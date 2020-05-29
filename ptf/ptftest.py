import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

#from yle_simple_switch.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from port_mapping import *

from pal_rpc.ttypes import *
from tm_api_rpc.ttypes import *

fp_ports = ["1/0", "2/0", "3/0", "4/0", "29/0", "30/0"]

def toInt8(n):
  n = n & 0xff
  return (n ^ 0x80) - 0x80

class Test(pd_base_tests.ThriftInterfaceDataPlane):
  def __init__(self):
    pd_base_tests.ThriftInterfaceDataPlane.__init__(self,["yle_simple_switch"])

  def setUp(self):
    pd_base_tests.ThriftInterfaceDataPlane.setUp(self)
    self.sess_hdl = self.conn_mgr.client_init()
    self.dev = 0
    self.dev_tgt = DevTarget_t(self.dev, hex_to_i16(0xFFFF))
    self.devPorts = []
    print("\nConnected to Device %d, Session %d" % (
self.dev, self.sess_hdl))

    board_type = self.pltfm_pm.pltfm_pm_board_type_get()
    if re.search("0x0234|0x1234|0x4234", hex(board_type)):
      self.platform_type = "mavericks"
    elif re.search("0x2234|0x3234", hex(board_type)):
      self.platform_type = "montara"
    ##print('[I] Platform type: {} - {}'.format(board_type, self.platform_type))

    # get the device ports from front panel ports
    for fp_port in fp_ports:
      port, channel = fp_port.split("/")
      devPort = \
        self.pal.pal_port_front_panel_port_to_dev_port_get(self.dev,
          int(port),
          int(channel))
      self.devPorts.append(devPort)

    if test_param_get('setup') or (not test_param_get('setup') and
      not test_param_get('cleanup')):
      # Determine which port actions to use
#      if hasattr(self, 'pltfm_pm') and hasattr(self.pltfm_pm, 'pltfm_pm_port_add'):
#        print('[I] Using pltfm_pm to set ports')
#        port_add = self.pltfm_pm.pltfm_pm_port_add
#        port_ena = self.pltfm_pm.pltfm_pm_port_enable
#        port_speed = pltfm_pm_port_speed_t.BF_SPEED_10G
#        port_fec = pltfm_pm_fec_type_t.BF_FEC_TYP_NONE
#
#    else:
#        print('[I] Using pal to set ports')
#        port_add = self.pal.pal_port_add
#        port_ena = self.pal.pal_port_enable
#        port_speed = pal_port_speed_t.BF_SPEED_100G
#        port_fec = pal_fec_type_t.BF_FEC_TYP_NONE
                # add and enable the platform ports
        for i in self.devPorts:
    	    print 'dev_port %s' % i
            self.pal.pal_port_add(0, i, pal_port_speed_t.BF_SPEED_100G, pal_fec_type_t.BF_FEC_TYP_REED_SOLOMON)
            self.pal.pal_port_an_set(0, i, 2);
            self.pal.pal_port_enable(0, i)
    # enable ports
#    for dev_port in self.devPorts:
#      print 'dev_port %s' % dev_port
#      try:
#        port_add(device=self.dev,
#          dev_port=dev_port,
#          ps=port_speed,
#          fec=port_fec)
#        port_ena(device=self.dev,
#          dev_port=dev_port)
#      except:
#        print('[I] Port {} added and enabled.'.format(dev_port))


  def runTest(self):
     # Test Parameters
     print("Start testing")
     ingress_port = self.devPorts[0]
     egress_port = self.devPorts[1]
     ig_mac_src = "00:11:11:11:11:11"
     eg_mac_src = "00:22:22:22:22:22"
     print("Populating table entries")

     # self.entries dictionary will contain all installed entry handles
#     self.entries={}
#     self.entries["forward"] = []
#     self.entries["forward"].append(
#       self.client.dmac_table_add_with_dmac_forward(
#       self.sess_hdl, self.dev_tgt,
#       yle_simple_switch_dmac_match_spec_t(
#         ethernet_srcAddr=macAddr_to_string(ig_mac_src)),
#       yle_simple_switch_dmac_forward_action_spec_t(
#         action_egress_spec=egress_port)))

  def tearDown(self):
     return
