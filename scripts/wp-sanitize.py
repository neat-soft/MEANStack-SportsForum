#!/usr/bin/env python

import re, sys

def file_tag_skipper(source, stag, etag):
    start = re.compile("^(.*?%s)(.*)$" % stag)
    end = re.compile("^.*?(%s.*)$" % etag)

    def after_cdata(s):
        m = end.match(s)
        if m:
            return m.group(1)
        return None

    c = 0
    inside = False
    for line in source:
        line = line.rstrip("\n")
        c += 1
        if inside:
            new = after_cdata(line)
            if new:
                yield new
                inside = False
        else:
            m = start.match(line)
            if m:
                yield m.group(1)
                new = after_cdata(m.group(2))
                if new:
                    yield new
                else:
                    inside = True
            else:
                yield line

def skip_tag(source, name):
    return file_tag_skipper(source, "<%s>" % name, "</%s>" % name)

# delete unprintable chars
del_map = ''.join(chr(i) for i in range(32))
def delete_ctrl(source):
    for line in source:
        yield line.translate(None, del_map)


# pipe line for skipping tags
def skip_all(source, tag_list):
    for tag in tag_list:
        source = skip_tag(source, tag)

    return source

processed = skip_all(delete_ctrl(sys.stdin), ["content:encoded", "wp:meta_value", "wp:attachment_url"])

for line in processed:
    print line
