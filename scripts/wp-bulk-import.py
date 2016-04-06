#!/usr/bin/env python

import sys, json
import xml.etree.ElementTree as etree
from pymongo import MongoClient

class CustomEntity:
    def __getitem__(self, key):
        return key

class WpParser(object):
    def __init__(self, site_name):
        self.nsmap = {}
        self.authors = {}
        self.first_comment = True
        self.post = {}
        self.site = site_name

    def add_ns(self, id, url):
        self.nsmap[id] = url

    def fix_tag(self, tag):
        if ":" in tag:
            ns, tag = tag.split(":", 1)
            return "{%s}%s" % (self.nsmap[ns], tag)
        return tag

    def get_text(self, elem, subtag):
        sub = elem.find(self.fix_tag(subtag))
        return (sub.text if sub is not None else "") or ""

    def get_all_text(self, elem, tags, prefix=""):
        full_tags = ["%s%s" % (prefix, t) for t in tags]
        contents = []
        for t in full_tags:
            contents.append(self.get_text(elem, t))
        return dict(zip(tags, contents))

    def process_comment(self, elem):
        tags = "id author author_email author date_gmt content approved \
                parent user_id".split()

        if self.first_comment:
            print json.dumps(dict(self.post, site=self.site))
            self.first_comment = False

        comment = self.get_all_text(elem, tags, prefix="wp:comment_")
        print json.dumps(comment)
        elem.clear()

    def process_author(self, elem):
        tags = "id email display_name".split()
        auth = self.get_all_text(elem, tags, "wp:author_")
        self.authors[auth["id"]] = auth
        elem.clear()

    def process_element(self, elem):
        if elem.tag == self.fix_tag("wp:comment"):
            self.process_comment(elem)
        elif elem.tag == self.fix_tag("link"):
            self.post["uri"] = elem.text
        elif elem.tag == self.fix_tag("title"):
            self.post["title"] = elem.text
        elif elem.tag == self.fix_tag("wp:post_id"):
            self.post["id"] = elem.text.strip()
        elif elem.tag == self.fix_tag("wp:post_type"):
            self.post_type = elem.text
        elif elem.tag == self.fix_tag("wp:author"):
            self.process_author(elem)
        elif elem.tag == self.fix_tag("item"):
            # next comment will be first in a new post
            self.first_comment = True
            self.post = {}
            # remove entire post from memory
            elem.clear()

def main(site_name, wp_file_name, *rest):
    wp = WpParser(site_name)
    parser = etree.XMLParser()
    parser.parser.UseForeignDTD(True)
    parser.entity = CustomEntity()

    with open(wp_file_name, "rt") as fin:
        events = 'start end start-ns end-ns'.split()
        for event, elem in etree.iterparse(fin, events=events, parser=parser):
            if event == 'start-ns':
                id, url = elem
                wp.add_ns(id, url)
            elif event == 'end':
                wp.process_element(elem)

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
