#ports = [128, 132, 168, 160] 
ports = [136, 128, 144, 140, 132, 160, 168]
ingress_pause_count = bfrt.ampel_switch.pipe.SwitchIngress.queueinfo.pause_count
ingress_pfc_count = bfrt.ampel_switch.pipe.SwitchIngress.queueinfo.pfc_count
egress_pause_count = bfrt.ampel_switch.pipe.SwitchEgress.gen_sq_pause.pause_count
egress_pfc_count = bfrt.ampel_switch.pipe.SwitchEgress.gen_sq_pause.pfc_count
egress_cp_count = bfrt.ampel_switch.pipe.SwitchEgress.icrc_cal.cp_count

for port in ports:
    ingress_pause = ingress_pause_count.get(port, from_hw=1, print_ents=False)
    print("ingress pause", port, ingress_pause.data[b'SwitchIngress.queueinfo.pause_count.f1'][1])

for port in ports:
    ingress_pfc = ingress_pfc_count.get(port, from_hw=1, print_ents=False)
    print("ingress pfc", port, ingress_pfc.data[b'SwitchIngress.queueinfo.pfc_count.f1'][1])

for port in ports:
    egress = egress_pause_count.get(port, from_hw=1, print_ents=False)
    print("egress pause", port, egress.data[b'SwitchEgress.gen_sq_pause.pause_count.f1'][1])

for port in ports:
    egress_pfc = egress_pfc_count.get(port, from_hw=1, print_ents=False)
    print("egress pfc", port, egress_pfc.data[b'SwitchEgress.gen_sq_pause.pfc_count.f1'][1])

for port in ports: #[136]:
    egress_cp = egress_cp_count.get(port, from_hw=1, print_ents=False)
    print("egress cp", port, egress_cp.data[b'SwitchEgress.icrc_cal.cp_count.f1'][1])


