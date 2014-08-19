#!/usr/bin/env python
#
# (C) Copyright 2014 Nuxeo SA (http://nuxeo.com/) and contributors.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the GNU Lesser General Public License
# (LGPL) version 2.1 which accompanies this distribution, and is available at
# http://www.gnu.org/licenses/lgpl-2.1.html
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# Contributors:
#     Julien Carsique
#
"""Update a trend of metrics gathered from ondemand-testandpush Jenkins jobs
Retrieve .ci-metrics file from a given ondemand-testandpush build
Retrieve also its build.xml and log files
Extract metrics, archive results in 'archives' and append them in 'metrics'

Parameters:
- JOB: the job name
- BUILD: the build number
- BUILD_DIR: for testing purpose, overwrite default paths
"""
import os
import sys
import fnmatch
import datetime
from commands import getstatusoutput
from xml.dom.minidom import parse

JOB = os.getenv('JOB', "ondemand-testandpush-sample")
BUILD = os.getenv('BUILD', "1")
BUILD_DIR = os.getenv('BUILD_DIR', './../../%s/builds/%s' % (JOB, BUILD))


def print_datetime(seconds=0, milliseconds=0):
    d = datetime.timedelta(seconds=seconds, milliseconds=milliseconds)
    return "%dh%dm%ds" % (d.seconds / 3600, d.seconds % 3600 / 60,
                          d.seconds % 3600 % 60)

def parse_build(dom):
    dom = dom.firstChild  # <build>
    for item in dom.childNodes:
        if item.nodeName == 'result':
            result = item.firstChild.nodeValue
        elif item.nodeName == 'builtOn':
            builtOn = item.firstChild.nodeValue
        elif item.nodeName == 'duration':
            duration = long(item.firstChild.nodeValue)
    dom = dom.getElementsByTagName('queuingDurationMillis')[0]
    queuingDuration = long(dom.firstChild.nodeValue)
    return (result, builtOn, duration, queuingDuration)

def parse_download(line):
    # [INFO] Downloaded: (...).jar (74 KB at 148.1 KB/sec)
    line = line[line.rfind('(') + 1:line.rfind(')')].split()
    size = float(line[0])
    if line[1] == "B":
        size = size / 1024
    speed = float(line[3])
    return size / speed

def parse_test(line):
    # Tests run: (...), Time elapsed: 0.063 sec - in (...)
    marker1 = "Time elapsed: "
    marker2 = " sec - in "
    if not marker1 in line:
        return 0
    seconds = line[line.index(marker1) + len(marker1):line.index(marker2)]
    if seconds:
        return float(seconds)
    else:
        return 0

# main
if not os.path.exists(BUILD_DIR):
    print "Invalid path : " + BUILD_DIR
    sys.exit(1)

# Parse build.xml file
build_xml = os.path.join(BUILD_DIR, "build.xml")
if not os.path.exists(build_xml):
    print "Missing file %s !" % build_xml
    sys.exit(1)
else:
    print "Reading %s ..." % build_xml
dom = parse(build_xml)
(result, builtOn, duration, queuingDuration) = parse_build(dom)

# Parse .ci-metrics file
ci_metrics = os.path.join(BUILD_DIR, "archive", ".ci-metrics")
if not os.path.exists(ci_metrics):
    print "Missing file %s !" % ci_metrics
    sys.exit(1)
else:
    print "Reading %s ..." % ci_metrics
with open(ci_metrics) as f:
    for line in f:
        (metric, time) = line.split()
        if metric == "Init":
            init = int(time)
        elif metric == "Maven":
            maven_build = int(time)
        elif metric == "Finalize":
            finalize = int(time)

# Parse console log
console_log = os.path.join(BUILD_DIR, "log")
if not os.path.exists(console_log):
    print "Missing file %s !" % console_log
    sys.exit(1)
else:
    print "Reading %s ..." % console_log
download_duration = 0
test_duration = 0
with open(console_log) as f:
    for line in f:
        if "Downloaded" in line:
            download_duration += parse_download(line)
        elif "Tests run:" in line:
            test_duration += parse_test(line)

# Archive results and update global metrics
if not os.path.exists('archives'):
    os.mkdir('archives')
archive = os.path.join('archives', JOB + "_" + BUILD)
print "Creating archive file: %s" % archive
with open(archive, "w") as f:
    f.write("Build=%s\nBuiltOn=%s\n"
            "Queuing=%s\nTotal=%s\nInit=%s\nBuild=%s\nFinalize=%s\n"
            "Download=%s\nTest=%s\n" % (
            JOB + "/" + BUILD, builtOn, queuingDuration, duration, init,
            maven_build, finalize, download_duration, test_duration))

header = ("%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s"
          "\t%-50s\t%s\n") % ("Result",
                              "Queuing",
                              "Total",
                              "Init",
                              "Build",
                              "Finalize",
                              "Download",
                              "Test",
                              "Job/Build", "Built On")
metrics = ("%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s"
           "\t%-50s\t%s\n") % (result,
                               print_datetime(milliseconds=queuingDuration),
                               print_datetime(milliseconds=duration),
                               print_datetime(seconds=init),
                               print_datetime(seconds=maven_build),
                               print_datetime(seconds=finalize),
                               print_datetime(seconds=download_duration),
                               print_datetime(seconds=test_duration),
                               JOB + "/" + BUILD, builtOn)
metrics_file = os.path.join(os.getcwd(), 'metrics')
if not os.path.exists(metrics_file):
    with open('metrics', "w") as f:
        print "Creating metrics file: %s" % metrics_file
        f.write(header)
else:
    print "Updating metrics file: %s" % metrics_file
with open('metrics', "a") as f:
    f.write(metrics)

print header, metrics
