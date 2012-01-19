#!/usr/bin/python
"""Build a FunkLoad trend report for a hudson job
"""
import os
import sys
import fnmatch
from commands import getstatusoutput
from xml.dom.minidom import parse


JOB = os.getenv('JOB', "FT-nuxeo-master-funkload-bench")
PERIODS = os.getenv('PERIODS', "15,30,160")
DIRNAME_PATTERN = os.getenv('DIRNAME_PATTERN', "testReader-201*")
BUILTON = os.getenv('BUILTON', 'chipolata')
HERE = os.curdir
BASE_URL = os.getenv('BASE_URL', 'http://qa.nuxeo.org/jenkins/job/FT-nuxeo-master-funkload-bench')
REPORT_BASE_NAME = os.getenv('REPORT_BASE_NAME', "trend-reader")


build_dir = './../../../%s/builds' % JOB
periods = [int(period) for period in PERIODS.split(',')]

# utils
class BaseFilter(object):
    """Base filter."""
    def __ror__(self, other):
        return other  # pass-thru
    def __call__(self, other):
        return other | self

class truncate(BaseFilter):
    """Middle truncate string up to length."""
    def __init__(self, length=14, extra='..'):
        self.length = length
        self.extra = extra
    def __ror__(self, other):
        if len(other) > self.length:
            mid_size = (self.length - 3) / 2
            other = other[:mid_size] + self.extra + other[-mid_size:]
        return other

def locate(pattern, root):
    """Locate all files matching supplied filename pattern"""
    for path, dirs, files in os.walk(os.path.abspath(root)):
        for filename in fnmatch.filter(files, pattern):
            yield os.path.join(path, filename)


# main

if not os.path.exists(build_dir):
    print "Invalid path : " + build_dir
    sys.exit(1)

builds = [build for build in os.listdir(build_dir) if build.startswith("201") and len(build) == 19]
builds.sort()
builds.reverse()
count = 0
reports = []
for build in builds:
    build_xml = os.path.join(build_dir, build, "build.xml")
    if not os.path.exists(build_xml):
        print "No hudson build.xml file found, skipping"
        continue
    dom = parse(build_xml)
    description = ''
    builtOn = ''
    number = ''
    result = ''
    try:
        for item in dom.documentElement.childNodes:
            if item.nodeName == 'description':
                description = item.childNodes[0].nodeValue
            if item.nodeName == 'result':
                result = item.childNodes[0].nodeValue
            elif item.nodeName == 'number':
                number = item.childNodes[0].nodeValue
            elif item.nodeName == 'builtOn':
                builtOn = item.childNodes[0].nodeValue
    except IndexError:
        pass
    if result in ('ABORTED', 'FAILURE'):
        continue
    if description.startswith('#'):
        continue
    print result, build

    # find index.rst
    indexes = locate('index.rst', os.path.join(build_dir, build))
    indexes = [index for index in indexes if fnmatch.fnmatch(os.path.basename(os.path.dirname(index)), DIRNAME_PATTERN)]
    for index in indexes:
        found = False
        for line in open(index).readlines():
            if BUILTON in line:
                found = True
                break
        if not found:
            continue
        report = os.path.dirname(index)
        reports.append(report)
        # add a bench metadata if none
        metadata_file = os.path.join(report, 'funkload.metadata')
        if True: # not os.path.exists(metadata_file):
            metadata = []
            if description:
                label = description # | truncate()
                metadata.append('label: ' + label)
                metadata.append(description)
            metadata.append("build: `%s <%s>`__" % (number, BASE_URL + '/' + number))
            metadata.append("builtOn: " + builtOn)
            metadata.append('`bench report <' + BASE_URL + '/' + number + '/artifact/trunk/report/' + os.path.basename(report) + '/index.html#page-stats>`__')
            metadata.append('`monitoring <' + BASE_URL + '/' + number + '/artifact/trunk/monitor/monitor.html>`__')
            f = open(metadata_file, "w+")
            f.write('\n'.join(metadata) + '\n')
            f.close()
    count += 1
    if count > max(periods):
        break

# build trends report
ret = 1
for period in periods:
    reps = reports[:period]
    reps.reverse()
    cmd = 'fl-build-report -r ' + REPORT_BASE_NAME + '-' + str(period) + ' --trend ' + ' '.join(reps)
    print "invoking: "  + cmd[:150] + "..."
    ret, output = getstatusoutput(cmd)
    print output

sys.exit(ret)
