import sys
import time
import logging
import os

from scapy.all import conf
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP, ARP
from scapy.contrib.mac_control import MACControlPause, MACControlClassBasedFlowControl
from scapy.all import *

#iface='enp216s0f0'
iface ='enps0f1'
class SQL(Packet):
    name = "SQ"
    fields_desc = [ ShortField("queueid", 0),
                    IntField("queuedepth", 0)]

bind_layers(Ether, SQL)

pause_pkt = Ether(dst='01:80:c2:00:00:01', src='00:00:00:00:00:00', type=0xABCD)/SQL()/Raw(RandString(size=236))
print 'pause frame len:', len(pause_pkt)
socket = conf.L2socket(iface=iface)

sec_count = 0
count =0
register_indices = [136, 128, 144, 140, 132]
try:
    start_time = time.time()
    while count < 100:
        sq_layer = pause_pkt[SQL]
        sq_layer.queueid = register_indices[count%len(register_indices)]
        sq_layer.queuedepth = 100
        #pause_pkt.show()
        socket.send(pause_pkt)
        count+=1
        if time.time() - start_time > sec_count:
            print 'Sent pause frame: ', count
            sec_count +=1
except KeyboardInterrupt:
    print 'Sent pause frame: ', count
    exit;
