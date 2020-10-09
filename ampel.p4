#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif
#include "headers.p4"
#include "struct.p4"
#include "parde.p4"
#include "sq.p4"
#define NACK_OP_CODE 1
//-----------------------------------------------------------------------------
// Destination MAC lookup
// - Bridge out the packet of the interface in the MAC entry.
// - Flood the packet out of all ports within the ingress BD.
//-----------------------------------------------------------------------------

control SwitchIngress(
        inout switch_header_t hdr2,
        inout switch_ingress_metadata_t ig_md2,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr,
        inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm){

    Register<bit<32>, bit<12>>(4096,0) kk_count;
    RegisterAction<bit<32>, bit<12>, bit<32>>(kk_count) kk_count_read = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
            read_value = value;
        }
    };

    
    action dmac_forward(PortId_t port) {
        ig_intr_md_for_tm.ucast_egress_port = port;
        kk_count_read.execute(0);
    }

	action dmac_miss() {
		ig_intr_md_for_dprsr.drop_ctl = 3w1;
        kk_count_read.execute(1);
	}

	table dmac {
		key = {
			hdr2.ethernet.dst_addr : exact;
		}

		actions = {
			dmac_forward;
			@defaultonly dmac_miss;
		}

		const default_action = dmac_miss;
		size = 1024;
	}
    table dmac_dbtopo {
        key = {
            ig_intr_md.ingress_port : exact;
            hdr2.ethernet.dst_addr : exact;
        }
        actions = {
            dmac_forward;
            @defaultonly dmac_miss;
        }
        const default_action = dmac_miss;
        size =1024;
    }

QueueInforPropogation() queueinfo;	
	apply{

//		dmac.apply();                                                                                                     
        dmac_dbtopo.apply();
        queueinfo.apply(hdr2, ig_md2, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm);	
	}

}

control SwitchEgress(
        inout switch_header_t hdr2,
        inout switch_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {

    Dcqcn() dcqcn;
	IcrcCalculation() icrc_cal;
	QueueInfoUpdate() queuedepth_update;
	GenSQPause() gen_sq_pause;
	apply {
        icrc_cal.apply(hdr2, eg_md, eg_intr_md); //cp-port
        dcqcn.apply(hdr2, eg_intr_md);
        queuedepth_update.apply(hdr2, eg_intr_md); //normal packet, seed packet 
        gen_sq_pause.apply(hdr2, eg_md, eg_intr_md); //mirror type
    }

}
Pipeline(SwitchIngressParser(),
        SwitchIngress(),
        SwitchIngressDeparser(),
        SwitchEgressParser(),
        SwitchEgress(),
        SwitchEgressDeparser()) pipe;

Switch(pipe) main;

