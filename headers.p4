/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2019-present Barefoot Networks, Inc.
 *
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains the property of
 * Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
 * technical concepts contained herein are proprietary to Barefoot Networks, Inc.
 * and its suppliers and may be covered by U.S. and Foreign Patents, patents in
 * process, and are protected by trade secret or copyright law.  Dissemination of
 * this information or reproduction of this material is strictly forbidden unless
 * prior written permission is obtained from Barefoot Networks, Inc.
 *
 * No warranty, explicit or implicit is provided, unless granted under a written
 * agreement with Barefoot Networks, Inc.
 *
 ******************************************************************************/

#ifndef _HEADERS_
#define _HEADERS_

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;

typedef bit<16> ether_type_t;
const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_PFC = 16w0x8803;//0x8808

typedef bit<8> ip_protocol_t;
const ip_protocol_t IP_PROTOCOLS_IPV4 = 4;
const ip_protocol_t IP_PROTOCOLS_UDP = 17;
const ip_protocol_t IP_PROTOCOLS_TCP = 6;

typedef bit<16> udp_port_t;
const udp_port_t UDP_PORT_ROCEV2 = 4791;

typedef bit<8> rocev2_protocol_t;
const rocev2_protocol_t ROCEV2_READ_REQEUST = 12;
const rocev2_protocol_t ROCEV2_READ_RESPONSE_FIRST = 13;
const rocev2_protocol_t ROCEV2_READ_RESPONSE_MIDDLE = 14;
const rocev2_protocol_t ROCEV2_READ_RESPONSE_LAST = 15;
const rocev2_protocol_t ROCEV2_READ_RESPONSE_ONLY = 16;
const rocev2_protocol_t ROCEV2_WRITE_REQUEST_ONLY = 10;
const rocev2_protocol_t ROCEV2_WRITE_REQUEST_FIRST = 6;
const rocev2_protocol_t ROCEV2_WRITE_REQUEST_MIDDLE = 7;
const rocev2_protocol_t ROCEV2_WRITE_REQUEST_LAST = 8;
const rocev2_protocol_t ROCEV2_WRTIE_RESPONSE_ACK = 17;

typedef bit<24> dst_qp_t;
typedef bit<8> rocev2_placeholder_t;
typedef bit<32> rocev2_crc_t;



/**/
typedef bit<8>  pkt_type_t;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;

#if __TARGET_TOFINO__ == 1
typedef bit<3> mirror_type_t;
#else
typedef bit<4> mirror_type_t;
#endif
const mirror_type_t MIRROR_TYPE_I2E = 1;
const mirror_type_t MIRROR_TYPE_E2E = 2;

/**/
header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}
header pfc_h {
    bit<16> opcode;
    bit<16> cev;
    bit<16> time0;
    bit<16> time1;
    bit<16> time2;
    bit<16> time3;
    bit<16> time4;
    bit<16> time5;
    bit<16> time6;
    bit<16> time7;
    //bit<224> pad;
    bit<208> pad;
    //bit<32> crc;
}

header ipv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4> data_offset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
    bit<96> options; // dedicated for rdma case
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> hdr_length;
    bit<16> checksum;
}


// RDMA over Converged Ethernet (RoCEv2)
header rocev2_bth_h {
    bit<8> opcode;
    bit<1> se;
    bit<1> migration_req;
    bit<2> pad_count;
    bit<4> transport_version;
    bit<16> partition_key;
    bit<1> f_res1;
    bit<1> b_res1;
    bit<6> reserved;
    bit<24> dst_qp;
    bit<1> ack_req;
    bit<7> reserved2;
    bit<24> packet_seq;
}

// RoCEv2 read request and write request
header rocev2_reth_h {
    bit<64> virtual_addr;
    bit<32> remote_key;
    bit<32> dma_len;
}

// RoCEv2 read response and write ack
header rocev2_aeth_h {
    bit<1> res;
    bit<2> opcode;
    bit<5> credit_count;
    bit<24> message_seq;
}

header tcp_payload_0_h {
    bit<80> payload;
}

header tcp_payload_1_h {
    bit<8> payload;
}

header tcp_payload_2_h {
    bit<8> payload;
}

header tcp_payload_3_h {
    bit<8> payload;
}

header tcp_payload_4_h {
    bit<8> payload;
}

header tcp_payload_5_h {
    bit<8> payload;
}

header tcp_payload_6_h {
    bit<8> payload;
}

header tcp_payload_workload_64_h {
    bit<64> payload;
}
header tcp_payload_workload_32_h {
    bit<32> payload;
}

header rocev2_payload_h {
    //bit<128> payload;
    bit<48> payload;
    //bit<64> payload;
}

header left_h{
    bit<96> content;
}

header rocev2_crc_h {
    bit<32> crc;
}
// Invariant CRC?
/*
header mirror_h {
  pkt_type_t  pkt_type;
}
*/
header mirror_header_type_0_h {}

#endif /* _HEADERS_ */

