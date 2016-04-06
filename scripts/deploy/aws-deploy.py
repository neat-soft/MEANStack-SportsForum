#!/usr/bin/env python

import sys, os, copy, operator, json
from pprint import pformat
from boto.opsworks.layer1 import OpsWorksConnection
import boto.ec2 as ec2
import time

ops = None
DOMAIN_NAME = "theburn-zone.com"
APP_NAME = "nodejs server 2"
CUSTOM_JSON = """
{
  "deploy": {
    "%(Shortname)s": {
      "nodejs": {
        %(extra_options)s
      }
    }
  }
}
"""

class InvalidKeyValue(Exception):
  pass

class InvalidStack(Exception):
  pass

class InvalidApp(Exception):
  pass

class InvalidNumberOfElbs(Exception):
  pass

class InvalidNumberOfLayers(Exception):
  pass

class NoInstanceAvailable(Exception):
  pass

class DeployAborted(Exception):
  pass

def select_stack_id(partial_name):
  all_stacks = ops.describe_stacks()["Stacks"]
  matching = [s for s in all_stacks if partial_name.lower() in s["Name"].lower()]
  if len(matching) == 0:
    print >>sys.stderr, "no stack matches the name '%s'" % partial_name
    for s in all_stacks:
      print >>sys.stderr, "\tid: '%(StackId)s' name: '%(Name)s'" % s
    raise InvalidStack(partial_name)
  elif len(matching) > 1:
    print >>sys.stderr, "multiple stacks matches for '%s'" % partial_name
    for s in matching:
      print >>sys.stderr, "\tid: '%(StackId)s' name: '%(Name)s'" % s
    raise InvalidStack(partial_name)

  return matching[0]["StackId"]

def find_layers_for_app(stack_id, app_short_name):
  return [l for l in ops.describe_layers(stack_id=stack_id)["Layers"]
    if l["Shortname"].startswith(app_short_name)]

def find_layers(stack_id, partial_name):
  return [l for l in ops.describe_layers(stack_id=stack_id)["Layers"]
    if partial_name in l["Name"] and l["Type"] == "custom"]

def select_elb_for_layers(stack_id, layers):
  ids = [l["LayerId"] for l in layers]
  elbs = [e for e in ops.describe_elastic_load_balancers(stack_id=stack_id)["ElasticLoadBalancers"]
    if e["LayerId"] in ids]
  if len(elbs) != 1:
    raise InvalidNumberOfElbs("found %d ELBs for layers %s, expected 1" %
      (len(elbs), ", ".join("'%(Name)s'" % l for l in layers)))

  return elbs[0]

def find_load_balancers(stack_id):
  return ops.describe_elastic_load_balancers(stack_id=stack_id)["ElasticLoadBalancers"]

def find_layer_instances(layer_id):
  return ops.describe_instances(layer_id=layer_id)["Instances"]

def find_instances(instance_ids):
  return ops.describe_instances(instance_ids=instance_ids)["Instances"]

def find_last_deployment(app_id, ins_ids):
  """Return the most recent deployment of <app_id> that affected one of the
  instances in the <ins_ids> list.
  """
  deps = [d for d in ops.describe_deployments(app_id=app_id)["Deployments"]
      if d["Command"]["Name"].lower() in ("deploy", "undeploy") and
          set.intersection(set(d["InstanceIds"]), set(ins_ids))]
  deps.sort(key=operator.itemgetter("CreatedAt"), reverse=True)
  return deps[0] if deps else None

def attach_elb_to_layer(elb, old, new):
  ops.detach_elastic_load_balancer(elb["ElasticLoadBalancerName"], old["LayerId"])
  ops.attach_elastic_load_balancer(elb["ElasticLoadBalancerName"], new["LayerId"])

def select_app(stack_id, partial_name):
  all_apps = ops.describe_apps(stack_id=stack_id)["Apps"]
  matching = [a for a in all_apps if partial_name.lower() in a["Name"].lower()]
  if len(matching) == 0:
    print >>sys.stderr, "no app matches the name '%s'" % partial_name
    for s in all_apps:
      print >>sys.stderr, "\tid: '%(AppId)s' name: '%(Name)s'" % s
    raise InvalidApp(partial_name)
  elif len(matching) > 1:
    print >>sys.stderr, "multiple apps matches for '%s'" % partial_name
    for s in matching:
      print >>sys.stderr, "\tid: '%(AppId)s' name: '%(Name)s'" % s
    raise InvalidApp(partial_name)

  return matching[0]

def deploy_app(stack_id, app_id, instance_ids, custom_json):
  dep_id = ops.create_deployment(
      stack_id=stack_id,
      command={ "Name": "deploy" },
      app_id=app_id,
      instance_ids=instance_ids,
      comment="deploy from %s" % sys.argv[0],
      custom_json=json.dumps(custom_json))["DeploymentId"]

  return dep_id

def descend_dict(d, path):
  for p in path:
    try:
      d = d[p]
    except KeyError:
      d[p] = {}
      d = d[p]

  return d

class AttrDict(dict):
  def __init__(self, *args, **kwargs):
    super(AttrDict, self).__init__(*args, **kwargs)
    self.__dict__ = self

def usage():
  print "usage: %s <stack> <app1> [params1] [<app2> [params2]]" % sys.argv[0]
  print """start applications in AWS OpsWorks by passing them CustomJSON"

  stack    name of the stack for deployment (fuzzy matched if unique)
  app      application name (fuzzy matched if unique)
  params   custom JSON in the following format:
           key1.subkey1=value key2.subkey2=value3 key3=value3
           which corresponds to the following JSON:
           'deploy' : {
             '<app_short_name>': {
               'key1': {"
                 'subkey1': 'value1'
               }
               'key2': {
                 'subkey2': 'value2'
               }
               'key3': 'value3'
               }
             }
           }
"""
  print "eg: %s production 'bzone app' nodejs.run_script=server.js environment.NODE_ENV=production scripts nodejs.run_script=jobs.js" % sys.argv[0]

def main(args):
  global ops

  if len(args) < 2:
    usage()
    return

  ops = OpsWorksConnection()
  stack_name = args[0]
  stack_id = select_stack_id(stack_name)

  app = AttrDict()
  app_list = []
  for arg in args[1:]:
    if "=" not in arg:
      if app:
        app_list.append(app)
      app = AttrDict(name=arg, params={})
    else:
      k, v = arg.split("=", 1)
      app.params[k] = v
  if app.name:
    app_list.append(app)

  all_instances = []
  must_start_instances = []
  must_stop_instances = []
  for app in app_list:
    app.info = select_app(stack_id, app.name)
    app.layers = [AttrDict(l) for l in find_layers_for_app(stack_id, app.info["Shortname"])]
    if not app.layers:
      raise InvalidNumberOfLayers("no layers available for app '%(Name)s' (%(Shortname)s)" % app.info)
    app.json = {
      "deploy": {
        app.info["Shortname"]: {
          }
        }
      }
    root = app.json["deploy"][app.info["Shortname"]]
    for k, v in app.params.iteritems():
      path = k.split(".")
      attr = path[-1]
      path = path[:-1]
      descend_dict(root, path)[attr] = v

    if len(app.layers) > 1:
      app.elb = select_elb_for_layers(stack_id, app.layers)
      active_layer = [l["LayerId"] for l in app.layers].index(app.elb["LayerId"])
      app.old_layer = app.layers[active_layer]
      app.new_layer = app.layers[1 - active_layer]
    else:
      app.new_layer = app.layers[0]

    for l in app.layers:
      l.instances = find_layer_instances(l["LayerId"])
      all_instances.extend(l.instances)
      must_start_instances.extend(i for i in l.instances if l == app.new_layer and i["Status"] == "stopped" and "AutoScalingType" not in i)
      must_stop_instances.extend(i for i in l.instances if l != app.new_layer and i["Status"] != "stopped" and "AutoScalingType" not in i)

    if not app.new_layer.instances:
      raise NoInstanceAvailable("no instances available for layer '%(Name)s'" % app.new_layer)

  # INFO
  for app in app_list:
    print "Application '%(Name)s' to be deployed on layers '%(LayerName)s' with instances" % dict(app.info, LayerName=app.new_layer["Name"])
    for i in app.new_layer.instances:
      print "\t%(Hostname)s - %(Architecture)s - %(InstanceType)s - %(Status)s" % i
    print "with custom JSON: %s" % pformat(app.json)
  # ^ INFO

  pending_instance_ids = [i["instanceId"] for i in must_start_instances]
  for id in pending_instance_ids:
    ops.start_instance(id)

  while pending_instance_ids:
    ins = [i for i in ops.describe_instances(instance_ids=pending_instance_ids)["Instances"] if i["Status"] != "online"]
    pending_instance_ids = [i["InstanceId"] for i in ins]
    if pending_instance_ids:
      print "Waiting 30 sec for instances to start: %s" % ", ".join(i["Hostname"] for i in ins)
      time.sleep(30)

  for app in app_list:
    print "Deploying '%(Name)s' (%(Shortname)s)" % app.info
    instance_ids = [i["InstanceId"] for i in app.new_layer.instances]
    prev_dep = find_last_deployment(app.info["AppId"], instance_ids)
    if prev_dep and "CustomJson" in prev_dep:
      print "\tprevious deployment (type '%s') done by %s on %s" % (
        prev_dep["Command"]["Name"], prev_dep["IamUserArn"].split(":user/")[-1], prev_dep["CreatedAt"])
    dep_id = deploy_app(stack_id, app.info["AppId"], instance_ids, app.json)

    # wait for deployment to be complete
    while True:
      dep = ops.describe_deployments(deployment_ids=[dep_id])["Deployments"][0]
      if dep["Status"] != "running":
        break
      print "\twaiting 60 sec for completion of deployment..."
      time.sleep(30)

    print "\tcompleted with status: %s" % dep["Status"]

    if len(app.layers) > 1:
      print "Attaching ELB '%(DnsName)s' to layer '%(Name)s'" % dict(app.elb, Name=app.new_layer["Name"])
      attach_elb_to_layer(app.elb, app.old_layer, app.new_layer)

  pending_instance_ids = [i["InstanceId"] for i in must_stop_instances]
  for id in pending_instance_ids:
    ops.stop_instance(id)

  while pending_instance_ids:
    ins = [i for i in ops.describe_instances(instance_ids=pending_instance_ids)["Instances"] if i["Status"] != "stopped"]
    pending_instance_ids = [i["InstanceId"] for i in ins]
    if pending_instance_ids:
      print "Waiting 30 sec for instances to stop: %s" % ", ".join(i["Hostname"] for i in ins)
      time.sleep(30)

  # TODO remove this or rewrite it?

'''
  prev_dep = find_last_deployment(app["AppId"], instance_ids)
  if prev_dep and "CustomJson" in prev_dep:
    print "Previous deployment (type '%s') done by %s on %s" % (
        prev_dep["Command"]["Name"], prev_dep["IamUserArn"].split(":user/")[-1], prev_dep["CreatedAt"])
    prev_custom = json.loads(prev_dep["CustomJson"])
    prev_kv = prev_custom["deploy"][app["Shortname"]]["nodejs"]
    diffs = dict((k, (v, custom_json_params[k] if k in custom_json_params else "")) for k, v in prev_kv.iteritems()
        if k not in custom_json_params or custom_json_params[k] != v)
    if diffs:
      print "*** WARNING: some params different from last deploy:"
    for k, (old, new) in diffs.iteritems():
      print "\t'%s' previously '%s' and now '%s'" % (k, old, new)

    while diffs:
      print "continue? (y/yes/n/no)"
      line = sys.stdin.readline().strip().lower()
      if line in ("y", "yes"):
        break
      elif line in ("n", "no"):
        raise DeployAborted("aborting deployment")
'''

if __name__ == "__main__":
  main(sys.argv[1:])

