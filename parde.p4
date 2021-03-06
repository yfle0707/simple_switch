/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2018-2019 Barefoot Networks, Inc.
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains the property of
 * Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
 * technical concepts contained herein are proprietary to Barefoot Networks,
 * Inc.
 * and its suppliers and may be covered by U.S. and Foreign Patents, patents in
 * process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material is
 * strictly forbidden unless prior written permission is obtained from
 * Barefoot Networks, Inc.
 *
 * No warranty, explicit or implicit is provided, unless granted under a
 * written agreement with Barefoot Networks, Inc.
 *
 *
 ******************************************************************************/

parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        // Parse resubmitted packet here.
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

parser TofinoEgressParser(
        packet_in pkt,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}


// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out switch_header_t hdr2,
        out switch_ingress_metadata_t ig_md2,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }
    /*
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition accept;
    }*/
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition select(hdr2.ethernet.ether_type,ig_intr_md.ingress_port) {
            (ETHERTYPE_IPV4, 152) : parse_ipv4_for_pause;
            (ETHERTYPE_IPV4, _) : parse_ipv4;
            default : accept;
        }
    }

    state parse_ipv4_for_pause {
        pkt.extract(hdr2.ipv4);
        transition select(hdr2.ipv4.protocol) {
            IP_PROTOCOLS_UDP : parse_udp_for_pause;
            default : accept;
        }
    }

    state parse_udp_for_pause {
        pkt.extract(hdr2.udp);
        transition select(hdr2.udp.dst_port) {
            UDP_PORT_ROCEV2 : parse_rocev2_bth_for_pause;
            default : accept;
        }
    }

    state parse_rocev2_bth_for_pause {
        pkt.extract(hdr2.rocev2_bth);
	    //qkmeng
        transition select(hdr2.rocev2_bth.opcode) {
            ROCEV2_WRITE_REQUEST_ONLY: parse_left; //
            ROCEV2_WRITE_REQUEST_FIRST: parse_left; //
            ROCEV2_WRITE_REQUEST_MIDDLE: parse_left;//
            ROCEV2_WRITE_REQUEST_LAST: parse_left;//
            default : accept;
        }
    }
    
    state parse_left {
        pkt.extract(hdr2.left);
        transition accept;
    } 


/*    
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition select(hdr2.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            ETHERTYPE_PFC : parse_pfc;
            default : accept;
        }
    }
*/

    state parse_pfc {
        pkt.extract(hdr2.pfc);
        transition parse_crc;
    }

    state parse_crc{
        pkt.extract(hdr2.rocev2_crc);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr2.ipv4);
        ig_md2.total_len = hdr2.ipv4.total_len;
        transition select(hdr2.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }


    state parse_tcp {
        pkt.extract(hdr2.tcp);
        pkt.extract(hdr2.special_label);
        transition select(hdr2.special_label.payload){
            0xABCDABCD: parse_src_dst_qpn;
            default: accept;
        }

    }

    state parse_src_dst_qpn{
        pkt.extract(hdr2.payload_src_qpn);
        pkt.extract(hdr2.payload_dst_qpn);
        transition accept;

    }

    state parse_udp {
        pkt.extract(hdr2.udp);
        transition select(hdr2.udp.dst_port) {
            UDP_PORT_ROCEV2 : parse_rocev2_bth;
            default : accept;
        }
    }

    state parse_rocev2_bth {
        pkt.extract(hdr2.rocev2_bth);
	    //qkmeng
        transition select(hdr2.rocev2_bth.opcode) {
            ROCEV2_READ_REQEUST: parse_rocev2_reth;
            ROCEV2_READ_RESPONSE_ONLY: parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_FIRST: parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_MIDDLE: parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_LAST: parse_rocev2_aeth;
            
            ROCEV2_WRITE_REQUEST_ONLY: parse_rocev2_reth;
            ROCEV2_WRITE_REQUEST_FIRST: parse_rocev2_reth;
            ROCEV2_WRITE_REQUEST_MIDDLE: parse_rocev2_payload_mirror;//parse_rocev2_payload;
            ROCEV2_WRITE_REQUEST_LAST: parse_rocev2_payload_mirror;//parse_rocev2_payload;
            ROCEV2_WRTIE_RESPONSE_ACK: parse_rocev2_aeth;
            default : accept;
        }
    }

    state parse_rocev2_reth {
        pkt.extract(hdr2.rocev2_reth);
        transition parse_rocev2_crc;
    }

    state parse_rocev2_aeth {
        pkt.extract(hdr2.rocev2_aeth);
        transition parse_rocev2_crc;
    }

    state parse_tcp_payload {
        pkt.extract(hdr2.tcp_payload_0);
        pkt.extract(hdr2.tcp_payload_1);
        pkt.extract(hdr2.tcp_payload_2);
        pkt.extract(hdr2.tcp_payload_3);
        pkt.extract(hdr2.tcp_payload_4);
        pkt.extract(hdr2.tcp_payload_5);
        pkt.extract(hdr2.tcp_payload_6);
        transition accept;
    }


    state parse_rocev2_payload_mirror {
        pkt.extract(hdr2.rocev2_payload_for_mirror_ex);
        transition parse_rocev2_crc;
    }

/*
    state parse_rocev2_payload {
        pkt.extract(hdr2.rocev2_payload);
        transition parse_rocev2_crc;
    }
*/
    state parse_rocev2_crc {
        pkt.extract(hdr2.rocev2_crc);
        transition accept;
    }
//old used-version parser
/*
    state parse_rocev2_reth {
        pkt.extract(hdr2.rocev2_reth);
        transition parse_rocev2_payload;
    }

    state parse_rocev2_aeth {
        pkt.extract(hdr2.rocev2_aeth);
        transition parse_rocev2_crc;
    }

    state parse_tcp_payload {
        pkt.extract(hdr2.tcp_payload_0);
        pkt.extract(hdr2.tcp_payload_1);
        pkt.extract(hdr2.tcp_payload_2);
        pkt.extract(hdr2.tcp_payload_3);
        pkt.extract(hdr2.tcp_payload_4);
        pkt.extract(hdr2.tcp_payload_5);
        pkt.extract(hdr2.tcp_payload_6);
        transition accept;
    }

    state parse_rocev2_payload {
        pkt.extract(hdr2.rocev2_payload);
        transition parse_rocev2_crc;
    }

    state parse_rocev2_crc {
        pkt.extract(hdr2.rocev2_crc);
        transition accept;
    }
*/
}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout switch_header_t hdr2,
        in switch_ingress_metadata_t ig_md2,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    Checksum() ipv4_checksum;

    apply {
    hdr2.ipv4.hdr_checksum = ipv4_checksum.update(
                {hdr2.ipv4.version,
                 hdr2.ipv4.ihl,
                 hdr2.ipv4.diffserv,
                 hdr2.ipv4.total_len,
                 hdr2.ipv4.identification,
                 hdr2.ipv4.flags,
                 hdr2.ipv4.frag_offset,
                 hdr2.ipv4.ttl,
                 hdr2.ipv4.protocol,
                 hdr2.ipv4.src_addr,
                 hdr2.ipv4.dst_addr});
        // TODO: update udp checksum
        pkt.emit(hdr2.ethernet); 
        pkt.emit(hdr2.pfc);
        //pkt.emit(hdr2.crc);
        pkt.emit(hdr2.ipv4);
        pkt.emit(hdr2.tcp);
        pkt.emit(hdr2.udp);
        pkt.emit(hdr2.rocev2_bth);
        pkt.emit(hdr2.left);
        pkt.emit(hdr2.rocev2_reth);
        pkt.emit(hdr2.rocev2_aeth);
        pkt.emit(hdr2.tcp_payload_0);
        pkt.emit(hdr2.tcp_payload_1);
        pkt.emit(hdr2.tcp_payload_2);
        pkt.emit(hdr2.tcp_payload_3);
        pkt.emit(hdr2.tcp_payload_4);
        pkt.emit(hdr2.tcp_payload_5);
        pkt.emit(hdr2.tcp_payload_6);

    //qkmeng-for-replay-homa-workload
        pkt.emit(hdr2.special_label);
        pkt.emit(hdr2.payload_src_qpn);
        pkt.emit(hdr2.payload_dst_qpn);
        
        //05_09
        //pkt.emit(hdr2.rocev2_payload);
        pkt.emit(hdr2.rocev2_payload_for_mirror_ex);
        pkt.emit(hdr2.rocev2_crc);
    }
}

// ---------------------------------------------------------------------------
// Egress parser
// ---------------------------------------------------------------------------
parser SwitchEgressParser(
        packet_in pkt,
        out switch_header_t hdr2,
        out switch_egress_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {

    TofinoEgressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition parse_ethernet;
    }
/* parser until ipv4
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition select(hdr2.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            default : accept;
        }
    }
    
    state parse_ipv4 {
        pkt.extract(hdr2.ipv4);
        transition accept;
    }
*/


/*  parser until ethernet
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition accept;
    }*/

    
    state parse_ethernet {
        pkt.extract(hdr2.ethernet);
        transition select(hdr2.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
  //          ETHERTYPE_PFC : parse_pfc;
            default : accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr2.ipv4);
        transition select(hdr2.ipv4.protocol) {
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr2.udp);
        transition select(hdr2.udp.dst_port) {
            UDP_PORT_ROCEV2 : parse_rocev2_bth;
            default : accept;
        }
    }

    state parse_rocev2_bth {
        pkt.extract(hdr2.rocev2_bth);
        transition select(hdr2.rocev2_bth.opcode) {
            ROCEV2_READ_RESPONSE_ONLY : parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_FIRST : parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_MIDDLE : parse_rocev2_aeth;
            ROCEV2_READ_RESPONSE_LAST : parse_rocev2_aeth;
            ROCEV2_WRTIE_RESPONSE_ACK : parse_rocev2_aeth;
            default : accept;
        }
    }
    state parse_rocev2_aeth {
        pkt.extract(hdr2.rocev2_aeth);
        transition parse_rocev2_crc;
    }

    state parse_rocev2_crc {
        pkt.extract(hdr2.rocev2_crc);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Egress Deparser
// ---------------------------------------------------------------------------
control SwitchEgressDeparser(
        packet_out pkt,
        inout switch_header_t hdr2,
        in switch_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
Mirror() mirror;
Checksum() ipv4_checksum;
    apply{
        //MirrorId_t sess_id;
        //sess_id=(bit<10>)(hdr2.ethernet.src_addr[7:0]);
        //qkmeng - mirror MIRROR_TYPE_E2E = 2;
    hdr2.ipv4.hdr_checksum = ipv4_checksum.update(
                {hdr2.ipv4.version,
                 hdr2.ipv4.ihl,
                 hdr2.ipv4.diffserv,
                 hdr2.ipv4.total_len,
                 hdr2.ipv4.identification,
                 hdr2.ipv4.flags,
                 hdr2.ipv4.frag_offset,
                 hdr2.ipv4.ttl,
                 hdr2.ipv4.protocol,
                 hdr2.ipv4.src_addr,
                 hdr2.ipv4.dst_addr});
        /*
        if(eg_dprsr_md.mirror_type == 0){
            mirror.emit<mirror_h>(sess_id, {eg_md.pkt_type});
        }*/
        if(eg_dprsr_md.mirror_type == 0){
            mirror.emit<mirror_header_type_0_h>(eg_md.sess_id, {});
        }
/*
        pkt.emit(hdr2.ethernet);
        pkt.emit(hdr2.ipv4);
        pkt.emit(hdr2.udp);
        pkt.emit(hdr2.rocev2_bth);
        pkt.emit(hdr2.rocev2_aeth);
        pkt.emit(hdr2.rocev2_crc);
*/

        pkt.emit(hdr2.ethernet);
//        pkt.emit(hdr2.pfc);
        pkt.emit(hdr2.ipv4);
        pkt.emit(hdr2.udp);
        pkt.emit(hdr2.rocev2_bth);
//        pkt.emit(hdr2.rocev2_reth);
        pkt.emit(hdr2.rocev2_aeth);
//        pkt.emit(hdr2.rocev2_payload);
        pkt.emit(hdr2.rocev2_crc);
    }
}

