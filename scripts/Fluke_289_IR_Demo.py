#!/usr/bin/python
#
# A quick demo of reading values from a Fluke 289 using the USB serial cable.
#
# Copyright (c) 2016 Kendrick Shaw
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
import serial
import io

ser = serial.Serial("/dev/ttyUSB0", 115200, timeout=0.100);
sio = io.TextIOWrapper(io.BufferedRWPair(ser,ser), newline='\r');

while True:
    sio.write(u'QM\r')
    sio.flush()
    lines = sio.read().split('\r')
    if lines[0] == u'0': # Success
        value,unit,state,attribute = lines[1].split(',')
        print("Measured {0} {1}, state {2}, attribute {3}".format(
            value,unit,state,attribute))
