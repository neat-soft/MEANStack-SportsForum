#!/usr/bin/env python

import sys
import datetime as dt

keyspace = sys.argv[1]

print '''
CREATE KEYSPACE %(keyspace)s WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': '1'
};

USE %(keyspace)s;
''' % locals()

start = dt.datetime(2000, 01, 01)
delta = dt.timedelta(days=1)
now = start

for i in range(366):
  tab = now.strftime("%m_%d_00_00")
  now += delta
  print '''
CREATE TABLE embed_count_%(tab)s (
  site text,
  conv text,
  err counter,
  ok counter,
  PRIMARY KEY (site, conv)
) WITH
  bloom_filter_fp_chance=0.010000 AND
  caching='KEYS_ONLY' AND
  comment='' AND
  dclocal_read_repair_chance=0.000000 AND
  gc_grace_seconds=864000 AND
  read_repair_chance=0.100000 AND
  replicate_on_write='true' AND
  populate_io_cache_on_flush='false' AND
  compaction={'class': 'SizeTieredCompactionStrategy'} AND
  compression={'sstable_compression': 'SnappyCompressor'};
''' % locals()
