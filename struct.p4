/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2015-2019 Barefoot Networks, Inc.

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
 ******************************************************************************/


#include "headers.p4"

//qkmeng
struct switch_ingress_metadata_t {
    mac_addr_t src_mac_addr;
    mac_addr_t dst_mac_addr;
    ipv4_addr_t src_ipv4_addr;
    ipv4_addr_t dst_ipv4_addr;
    bit<16> total_len;
    bit<8> dst_qp_1;
    bit<8> dst_qp_2;
    bit<8> dst_qp_3;
    bit<8> dst_qp_4;
    bit<8> dst_qp_5;
    bit<8> dst_qp_6;
    bit<24> dst_qp;
    bit<32> cache_info_dst_qp;
    bit<24> cache_info_packet_seq;
    bit<32> cache_info_message_seq;
    bit<16> cache_info_ip_id;
    //qkmeng
 //   bit<12> src_qp;
 //   bit<12> store_qp;
    //bit<24> bth_packet_seq;
    bit<32> nack_flag;
    MirrorId_t sess_id;

    bit<64> for_crc1;
    bit<64> for_crc2;
    bit<64> for_crc3;
    bit<64> for_crc4;
    bit<64> for_crc5;
    bit<64> for_crc6;
    bit<64> for_crc7;
    //bit<48> for_crc8;
    bit<32> for_crc8;

    bit<32> crc_mid;

    mac_addr_t for_stage_0;
    mac_addr_t for_stage_1;
    mac_addr_t for_stage_2;
    mac_addr_t for_stage_3;
    mac_addr_t for_stage_4;
    mac_addr_t for_stage_5;
    mac_addr_t for_stage_6;
    mac_addr_t for_stage_7;
    mac_addr_t for_stage_8;
    mac_addr_t for_stage_9;

    bit<8>ingress_port;
}

struct switch_egress_metadata_t {
    bit<64> crc_part_1;
    bit<64> crc_part_2;
    bit<64> crc_part_3;
    bit<64> crc_part_4;
    bit<64> crc_part_5;
    bit<64> crc_part_6;
    bit<32> crc_part_7;
    bit<32> crc_final;
    //bit<48> diff_time;
    //bit<48> initial_egr_timestamp;
    //bit<48> egress_global_tstamp;
    bit<32> s1;
    bit<32> s2;
    //bit<32> s3;
    MirrorId_t sess_id;
    pkt_type_t pkt_type;
}

//qkmeng
struct switch_header_t {
    ethernet_h ethernet;
    pfc_h pfc;
    //bit<32> crc;
    ipv4_h ipv4;
    tcp_h tcp;
    udp_h udp;
    rocev2_bth_h rocev2_bth;
    rocev2_reth_h rocev2_reth;
    rocev2_aeth_h rocev2_aeth;

    left_h left;

    tcp_payload_0_h tcp_payload_0;
    tcp_payload_1_h tcp_payload_1;
    tcp_payload_2_h tcp_payload_2;
    tcp_payload_3_h tcp_payload_3;
    tcp_payload_4_h tcp_payload_4;
    tcp_payload_5_h tcp_payload_5;
    tcp_payload_6_h tcp_payload_6;
    
//    tcp_payload_workload_64_h gid_global_interface_id; 
//    tcp_payload_workload_64_h gid_global_subnet_prefix;
//    tcp_payload_workload_32_h lid;
//    tcp_payload_workload_32_h qpn;
//    tcp_payload_workload_32_h psn;
//    tcp_payload_workload_32_h qpn_data_pkt;

    //for rdmaStudy
    tcp_payload_workload_32_h special_label;
    tcp_payload_workload_32_h payload_src_qpn;
    tcp_payload_workload_32_h payload_dst_qpn;

    //rocev2_payload_h rocev2_payload;
    rocev2_payload_h  rocev2_payload_for_mirror_ex;//128

    rocev2_crc_h rocev2_crc;
    MirrorId_t egr_mir_ses;
    bit<12> src_qp;
    bit<12> store_qp;
//    bit<32> nack_flag;
//    bit<32> large_seq_flag;
//    bit<8> ori_pass_egress;
}

