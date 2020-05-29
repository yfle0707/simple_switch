import socket

hostname = socket.gethostname()


# Configure front-panel ports
fp_ports = []

if hostname == 'tofino1':
    fp_ports = [1]
elif hostname == 'tofino2':
    fp_ports = [31]
elif hostname == 'wisc-tofino-0':
    fp_ports = [1, 2, 3]
for fp_port in fp_ports:
    for lane in range(1):
        dp = bfrt.port.port_hdl_info.get(conn_id=fp_port, chnl_id=lane, print_ents=False).data[b'$DEV_PORT']
        if hostname =="tofino2":
            bfrt.port.port.add(dev_port=dp, speed='BF_SPEED_10G', fec='BF_FEC_TYP_NONE', auto_negotiation=2, port_enable=True)
 #       elif hostname == "wisc-tofino-0":
 #           bfrt.port.port.add(dev_port=dp, speed='BF_SPEED_100G', fec='BF_FEC_TYP_REED_SOLOMON', auto_negotiation=2, port_enable=True)


# Add entries to the l2_forward table
if hostname == 'tofino2':   
    l2_forward = bfrt.pfc_pause.pipe.SwitchIngress.l2_forward
    l2_forward.add_with_forward(dst_addr=0x6cb3115309b0, port=128)
    l2_forward.add_with_forward(dst_addr=0x6cb3115309b2, port=129)
    l2_forward.add_with_forward(dst_addr=0x6cb31153099c, port=130)
    l2_forward.add_with_forward(dst_addr=0x0108c2000001, port=130)
elif hostname == 'wisc-tofino-0':
    dmac = bfrt.yle_switch.pipe.SwitchIngress.dmac
    dmac.add_with_dmac_forward(dst_addr=0xb8599fc4a10f, port=136)
    dmac.add_with_dmac_forward(dst_addr=0xb8599fc4a0ff, port=128)
    dmac.add_with_dmac_forward(dst_addr=0xb8599fc4a0f7, port=144)
    rocev2 = bfrt.yle_switch.pipe.SwitchIngress.rocev2
    rocev2.add_with_rocev2_hit(src_addr=0xb8599fc4a10f, port=136)
    rocev2.add_with_rocev2_hit(src_addr=0xb8599fc4a0ff, port=128)
    rocev2.add_with_rocev2_hit(src_addr=0xb8599fc4a0f7, port=144)

if hostname == 'tofino2':
# Setup ARP broadcast for the active dev ports
    active_dev_ports = [128,129,130]
    bfrt.pre.node.add(multicast_node_id=0, multicast_rid=0, multicast_lag_id=[], dev_port=active_dev_ports)
    bfrt.pre.mgid.add(mgid=1, multicast_node_id=[0], multicast_node_l1_xid_valid=[False], multicast_node_l1_xid=[0])
