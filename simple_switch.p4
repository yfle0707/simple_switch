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

#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif
#include "headers.p4"
#include "struct.p4"
//#include "shared/dtel.p4"
//#include "shared/types.p4"

//#include <tofino/primitives.p4>
//qkmeng -- NAK delay
//#include "delay_time.p4"

#include "parde.p4"

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
                inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
                inout ingress_intrinsic_metadata_for_tm_t ig_tm_md){

        Register<bit<32>, bit<12>>(4096, 0) rocev2_dst_qp_reg;
        RegisterAction<bit<32>, bit<12>, bit<32>>(rocev2_dst_qp_reg) rocev2_dst_qp_reg_read = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value = value;
                }
        };

        RegisterAction<bit<32>, bit<12>, bit<32>>(rocev2_dst_qp_reg) rocev2_dst_qp_reg_write = {
                void apply(inout bit<32> value) {
                        value = (bit<32>)hdr2.store_qp;
                        //value = value +1;
                }
        };
        Register<bit<16>, bit<12>>(4096, 0) rocev2_ip_id_reg;
        RegisterAction<bit<16>, bit<12>, bit<16>>(rocev2_ip_id_reg) rocev2_ip_id_reg_read = {
                void apply(inout bit<16> value, out bit<16> read_value) {
                        value = value + 1;
                        read_value = value;
                }
        };


        Register<bit<32>, bit<12>>(4096,26777216) nack_seq;
        RegisterAction<bit<32>, bit<12>, bit<32>>(nack_seq) nack_seq_set = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                }
        };

        Register<bit<32>, bit<12>>(4096,0) kk_count;
        RegisterAction<bit<32>, bit<12>, bit<32>>(kk_count) kk_count_read = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value = value + 1;
                        read_value = value;
                }
        };

        Register<bit<64>, bit<64>>(4096,0) kk_ts0;
        RegisterAction<bit<64>, bit<12>, bit<64>>(kk_ts0) kk_ts0_read = {
                void apply(inout bit<64> value, out bit<64> read_value) {
                        //value =  (bit<64>)ig_intr_md.ingress_mac_tstamp; 
                        value = (bit<64>)ig_prsr_md.global_tstamp;
                }
        };

        Register<bit<64>, bit<64>>(4096,0) kk_ts1;
        RegisterAction<bit<64>, bit<12>, bit<64>>(kk_ts1) kk_ts1_read = {
                void apply(inout bit<64> value, out bit<64> read_value) {
                       // value =  (bit<64>)ig_intr_md.ingress_mac_tstamp; 
                        value = (bit<64>)ig_prsr_md.global_tstamp;
                }
        };
        Register<bit<64>, bit<12>>(4096,0) kk_ts2;
        RegisterAction<bit<64>, bit<12>, bit<64>>(kk_ts2) kk_ts2_read = {
                void apply(inout bit<64> value, out bit<64> read_value) {
                       // value = (bit<64>)ig_intr_md.ingress_mac_tstamp;
                        value = (bit<64>)ig_prsr_md.global_tstamp;
                }
        };



        RegisterAction<bit<32>, bit<12>, bit<32>>(nack_seq) nack_seq_get = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value=0;
                        //if((bit<32>)hdr2.rocev2_bth.packet_seq!=value && value!=){//qkmeng-debug
                        //    read_value=value;
                        //}
                        if((bit<32>)hdr2.rocev2_bth.packet_seq==value){
                                value=26777216;
                                read_value= 6;
                        }
                        if(value==26777216){
                                read_value= 6;
                        }
                }
        };

        //This is for update 
        Register<bit<32>, bit<12>>(4096,26777216) nack_copy;
        RegisterAction<bit<32>, bit<12>, bit<32>>(nack_copy) nack_copy_set = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                }
        };

        RegisterAction<bit<32>, bit<12>, bit<32>>(nack_copy) nack_copy_get = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value=0;
                        if((bit<32>)hdr2.rocev2_bth.packet_seq==value){
                                value=26777216;
                                read_value=6;
                        }
                }
        };

        Register<bit<32>, bit<12>>(4096, 0) round_flag;
        RegisterAction<bit<32>, bit<12>, bit<32>>(round_flag) round_flag_change = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        if(value==0){
                                value=1;
                                read_value=1;
                        }
                        if(value==1){
                                value=0;
                                read_value=0;
                        }

                }
        };

        RegisterAction<bit<32>, bit<12>, bit<32>>(round_flag) round_flag_read = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value = value;
                }
        };

        /*
           Register<bit<32>, bit<2>>(4, 0) reg_count;
           RegisterAction<bit<32>, bit<2>, bit<32>>(reg_count) reg_count_do = {
           void apply(inout bit<32> value, out bit<32> read_value) {
           value=(bit<32>)hdr2.rocev2_bth.packet_seq;
           }
           };
         */

        Register<bit<32>, bit<12>>(4096, 0) reg_count;
        RegisterAction<bit<32>, bit<12>, bit<32>>(reg_count) reg_count_do = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value=value+1;
                        read_value=value;
                }
        };

        /*
           Register<bit<32>, bit<1>>(2, 26777216) prev_nack;
           RegisterAction<bit<32>, bit<1>, bit<32>>(prev_nack) prev_nack_do = {
           void apply(inout bit<32> value, out bit<32> read_value) {
           read_value=0;
           if((bit<32>)hdr2.rocev2_bth.packet_seq==value){
           read_value=6;
           }
           if((bit<32>)hdr2.rocev2_bth.packet_seq!=value){
           value = (bit<32>)hdr2.rocev2_bth.packet_seq;
           }
           }
           };
         */

        Register<bit<32>, bit<1>>(2, 0) var;
        RegisterAction<bit<32>, bit<1>, bit<32>>(var) var_value = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value= value+1; //hdr2.pfc.crc;
                }
        };
        action dmac_forward(PortId_t port) {
                ig_tm_md.ucast_egress_port = port;
                ig_tm_md.ingress_cos = 0;
                ig_tm_md.qid = 0;
        }

        action dmac_miss() {
                ig_dprsr_md.drop_ctl = 3w1;
        }
        //qkmeng -- drop the deflected packets
        action packet_drop(){
                ig_dprsr_md.drop_ctl = 3w1;
        }

        action deflect_on_drop(){
                ig_tm_md.deflect_on_drop =1w1;
        }

        action no_deflect_on_drop(){
                ig_tm_md.deflect_on_drop =1w0;
        }

        action write_dst_qp_reg(bit<12> con){
                rocev2_dst_qp_reg_write.execute(con);
        }

        action read_dst_qp_reg(bit<12> con){
                ig_md2.cache_info_dst_qp=rocev2_dst_qp_reg_read.execute(con);
        }
        action gen_pfc(){
                hdr2.ipv4.setInvalid();
                hdr2.udp.setInvalid();
                hdr2.rocev2_aeth.setInvalid();
                hdr2.rocev2_bth.setInvalid();
                hdr2.rocev2_reth.setInvalid();
                //hdr2.rocev2_payload.setInvalid();
                hdr2.left.setInvalid();
                hdr2.rocev2_payload_for_mirror_ex.setInvalid();
                hdr2.rocev2_crc.setInvalid();
                hdr2.pfc.setValid();
                //PFC pkts (802.1Qbb 66B) -- dstmac(6B),srcmac(6B),TYPE(2B8808),Opcode(2B0101),CEV(2B),Time0-7(8*2B),Pad(28B),CRC(4B)
                bit<48> ori_src_mac;
                bit<48> ori_dst_mac;
                ori_src_mac = hdr2.ethernet.src_addr;
                ori_dst_mac = hdr2.ethernet.dst_addr;
                hdr2.ethernet.src_addr = 0x000001000000;//ori_dst_mac;
                hdr2.ethernet.dst_addr = ori_src_mac;
                hdr2.ethernet.ether_type = 0x8808;
                hdr2.pfc.opcode = 16w0x0101;
                hdr2.pfc.cev = 0x0001;//for priority
                hdr2.pfc.time0 = 0x4E2;//3E8;//0x4E2;//1250 unit  each unit is 512bit time
                hdr2.pfc.time1 = 0;
                hdr2.pfc.time2 = 0;
                hdr2.pfc.time3 = 0;
                hdr2.pfc.time4 = 0;
                hdr2.pfc.time5 = 0;
                hdr2.pfc.time6 = 0;
                hdr2.pfc.time7 = 0;
                hdr2.pfc.pad = 0;
                //hdr2.rocev2_crc.setInvalid();
        }    
        action rocev2_hit(PortId_t port) {
                // exchange the source and destination mac
                bit<48>ori_mac_src_addr;
                bit<48>ori_mac_dst_addr;
                ori_mac_src_addr=hdr2.ethernet.src_addr;
                ori_mac_dst_addr=hdr2.ethernet.dst_addr;
                hdr2.ethernet.src_addr=ori_mac_dst_addr;
                hdr2.ethernet.dst_addr=ori_mac_src_addr;
                // exchange the source and destination ip
                // change ip len
                bit<32>ori_ipv4_src_addr;
                bit<32>ori_ipv4_dst_addr;
                ori_ipv4_src_addr=hdr2.ipv4.src_addr;
                ori_ipv4_dst_addr=hdr2.ipv4.dst_addr;
                hdr2.ipv4.src_addr=ori_ipv4_dst_addr;
                hdr2.ipv4.dst_addr=ori_ipv4_src_addr;

                hdr2.ipv4.total_len = 16w48;
                //qkmeng_debug
                hdr2.ipv4.identification = 1;
                // change udp len
                hdr2.udp.hdr_length = 16w28;
                // modify BTH header
                //qkmeng_debug
                hdr2.rocev2_bth.dst_qp = (bit<24>)ig_md2.cache_info_dst_qp;
                hdr2.rocev2_bth.ack_req = 1w0;
                //hdr2.rocev2_bth.packet_seq = (bit<24>)ig_md2.cache_info_packet_seq;
                //hdr2.rocev2_bth.packet_seq = 24w2;
                // remove RETH header
                // remove RoCEv2 payload();
                //hdr2.rocev2_payload.setInvalid();
                hdr2.rocev2_payload_for_mirror_ex.setInvalid();

                // insert AETH header
                hdr2.rocev2_aeth.setValid();
                hdr2.rocev2_aeth.res = 1w0;
                //hdr2.rocev2_aeth.opcode = 2w0;
                //qkmeng -- if send NAK then opcode is 2w3
                hdr2.rocev2_aeth.opcode = 2w1; //2w3;//2w1;
                hdr2.rocev2_aeth.credit_count = 5w2; //5w0;//5w1;
                hdr2.rocev2_aeth.message_seq = 24w0;//(bit<24>)ig_md2.cache_info_message_seq;
                //qkmeng
                hdr2.rocev2_crc.crc = 0xffffffff;
                //send to where it from
                dmac_forward(port);
        }

        //qkmeng -- this table  

        //qkmeng -- table recirculate is used to drop the deflected packets.
        table large_sequence_drop{
                key={}
                actions ={
                        packet_drop;
                }
                const defaut_action = packet_drop;
                size = 1024;
        }

        table set_deflect_on_drop{
                key={}
                actions ={
                        deflect_on_drop;
                }
                const default_action = deflect_on_drop;
                size = 1024;
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

        table rocev2 {
                key = {
                        hdr2.ethernet.src_addr : exact;
                }

                actions = {
                        rocev2_hit;
                        @defaultonly dmac_miss;
                }

                const default_action = dmac_miss;
                size = 1024;
        }

        action src_qp_do() {
                //        hdr2.src_qp[11:8] = hdr2.qpn_data_pkt.payload[19:16];
                //        hdr2.src_qp[7:4] = hdr2.qpn_data_pkt.payload[31:28];
                //        hdr2.src_qp[3:0] = hdr2.qpn_data_pkt.payload[27:24];
                //        hdr2.store_qp[11:8] = hdr2.qpn.payload[19:16];
                //        hdr2.store_qp[7:4] = hdr2.qpn.payload[31:28];
                //        hdr2.store_qp[3:0] = hdr2.qpn.payload[27:24];
                hdr2.store_qp[11:8] = hdr2.payload_src_qpn.payload[11:8];
                hdr2.store_qp[7:4] = hdr2.payload_src_qpn.payload[7:4];
                hdr2.store_qp[3:0] = hdr2.payload_src_qpn.payload[3:0];
                hdr2.src_qp[11:8] = hdr2.payload_dst_qpn.payload[11:8]; //after revert, we can find the sender's qp by searching dst qp
                hdr2.src_qp[7:4] = hdr2.payload_dst_qpn.payload[7:4];
                hdr2.src_qp[3:0] = hdr2.payload_dst_qpn.payload[3:0]; 
        }


        apply {
                /* SQ+SFN*/
                if(hdr2.payload_src_qpn.isValid()){ //parse qp number
                        src_qp_do();
                        write_dst_qp_reg(hdr2.src_qp); 
                } else if(hdr2.rocev2_bth.isValid()){  //RoCE v2 packets
                        
                        if(ig_intr_md.ingress_port==152){//From Deflected port, to send PAUSE
                                gen_pfc();            
                                reg_count_do.execute(0);
                        } else if(ig_intr_md.ingress_port==148){//From Deflected port, to send NACK //from 156->148
                                read_dst_qp_reg(hdr2.rocev2_bth.dst_qp[11:0]);
                                //nack_seq_set.execute(hdr2.rocev2_bth.dst_qp[11:0]);
                                //nack_copy_set.execute(hdr2.rocev2_bth.dst_qp[11:0]);
                                if(hdr2.rocev2_bth.opcode == ROCEV2_WRITE_REQUEST_ONLY || hdr2.rocev2_bth.opcode == ROCEV2_WRITE_REQUEST_FIRST){
                                        hdr2.rocev2_reth.setInvalid();
                                }
                                hdr2.rocev2_bth.opcode = ROCEV2_WRTIE_RESPONSE_ACK;
                                rocev2.apply();
                        }else{
                                if(ig_intr_md.ingress_port==144){ //node 3
                                        bit<32> kk1;
                                        bit<32> kk2;

                                        kk1=kk_count_read.execute(hdr2.rocev2_bth.packet_seq[11:0]);
                                        if(kk1==0){
                                                kk_ts0_read.execute(hdr2.rocev2_bth.packet_seq[11:0]);
                                        }
                                        if(kk1==1){
                                                kk_ts1_read.execute(hdr2.rocev2_bth.packet_seq[11:0]);
                                        }
                                        if(kk1==2){
                                                kk_ts2_read.execute(hdr2.rocev2_bth.packet_seq[11:0]);
                                        }
                                }
                        }

                } 
                dmac.apply();

                //                set_deflect_on_drop.apply();

        }
}

control SwitchEgress(
                inout switch_header_t hdr2,
                inout switch_egress_metadata_t eg_md,
                in egress_intrinsic_metadata_t eg_intr_md,
                in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
                inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
                inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {

        Register<bit<32>, bit<12>>(4096, 1) round;
        RegisterAction<bit<32>, bit<12>, bit<32>>(round) round_judge = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value = 0;
                        if((bit<32>)hdr2.rocev2_bth.reserved2!=value){
                                //need to deflect;
                                value = (bit<32>)hdr2.rocev2_bth.reserved2;
                                read_value=6; 
                        }
                }
        };
        Register<bit<32>, bit<12>>(4096, 0) ee_count;
        RegisterAction<bit<32>, bit<12>, bit<32>>(ee_count) ee_count_read = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value = value +1;
                        read_value =value;
                }
        };

        Register<bit<64>, bit<64>>(4096,0) ee_ts1;
        RegisterAction<bit<64>, bit<12>, bit<64>>(ee_ts1) ee_ts1_read = {
                void apply(inout bit<64> value, out bit<64> read_value) {
                        value = (bit<64>)eg_intr_from_prsr.global_tstamp;
                }
        };
             //use
        Register<bit<32>, bit<12>>(4096, 26777216) sequence;
        RegisterAction<bit<32>, bit<12>, bit<32>>(sequence) sequence_judge = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value=0;
                        if((bit<32>)hdr2.rocev2_bth.packet_seq<=value+1 && value!=26777216){
                                value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                                read_value=6;
                        }
                        if(value==26777216){
                                value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                                read_value=6;
                        }
                }
        };

        Register<bit<32>, bit<1>>(2, 0) record_nack;
        RegisterAction<bit<32>, bit<1>, bit<32>>(record_nack) record_nack_do = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                }
        };

        Register<bit<32>, bit<1>>(2, 0) record_ack;
        RegisterAction<bit<32>, bit<1>, bit<32>>(record_ack) record_ack_do = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value=(bit<32>)hdr2.rocev2_bth.packet_seq;
                }
        };

        Register<bit<32>, bit<1>>(1, 0) test;
        RegisterAction<bit<32>, bit<1>, bit<32>>(test) test_read = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value = value+1;
                }
        };

        Register<bit<32>, bit<1>>(1, 0) test2;
        RegisterAction<bit<32>, bit<1>, bit<32>>(test2) test_read2 = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        value = value+1;
                }
        };

        Register<bit<32>, bit<1>>(1, 0) ecn;
        RegisterAction<bit<32>, bit<1>, bit<32>>(ecn) ecn_mark = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        read_value=0;
                        if(eg_intr_md.deq_qdepth>1250){
                                read_value=6;
                        }
                }
        };

        Register<bit<32>, bit<1>>(1, 0) queue_reg;
        RegisterAction<bit<32>, bit<1>, bit<32>>(queue_reg) queue_reg_do = {
                void apply(inout bit<32> value, out bit<32> read_value) {
                        if((bit<32>)eg_intr_md.deq_qdepth>value){
                                value = (bit<32>)eg_intr_md.deq_qdepth;
                        }
                }
        };

        Hash<bit<32>>(HashAlgorithm_t.CRC32) rocev2_hash;

        action update_crc_12() {
                eg_md.crc_part_1 = 64w0xffffffffffffffff;
                eg_md.crc_part_2[63:60] = hdr2.ipv4.version;
                eg_md.crc_part_2[59:56] = hdr2.ipv4.ihl;
                eg_md.crc_part_2[55:48] = 8w0xff;
                eg_md.crc_part_2[47:32] = hdr2.ipv4.total_len;
                eg_md.crc_part_2[31:16] = hdr2.ipv4.identification;
                eg_md.crc_part_2[15:13] = hdr2.ipv4.flags;
                eg_md.crc_part_2[12:0] = hdr2.ipv4.frag_offset;
        }
        action update_crc_3() {
                eg_md.crc_part_3[63:56] = 8w0xff;
                eg_md.crc_part_3[55:48] = hdr2.ipv4.protocol;
                eg_md.crc_part_3[47:32] = 16w0xffff;
                eg_md.crc_part_3[31:0] = hdr2.ipv4.src_addr;
        }
        action update_crc_4() {
                eg_md.crc_part_4[63:32] = hdr2.ipv4.dst_addr;
                eg_md.crc_part_4[31:16] = hdr2.udp.src_port;
                eg_md.crc_part_4[15:0] = hdr2.udp.dst_port;
        }
        action update_crc_5() {
                eg_md.crc_part_5[63:48] = hdr2.udp.hdr_length;
                eg_md.crc_part_5[47:32] = 16w0xffff;
                eg_md.crc_part_5[31:24] = hdr2.rocev2_bth.opcode;
                eg_md.crc_part_5[23:23] = hdr2.rocev2_bth.se;
                eg_md.crc_part_5[22:22] = hdr2.rocev2_bth.migration_req;
                eg_md.crc_part_5[21:20] = hdr2.rocev2_bth.pad_count;
                eg_md.crc_part_5[19:16] = hdr2.rocev2_bth.transport_version;
                eg_md.crc_part_5[15:0] = hdr2.rocev2_bth.partition_key;

        }
        action update_crc_6() {
                eg_md.crc_part_6[63:56] = 8w0xff;
                eg_md.crc_part_6[55:32] = hdr2.rocev2_bth.dst_qp;
                eg_md.crc_part_6[31:31] = hdr2.rocev2_bth.ack_req;
                eg_md.crc_part_6[30:24] = hdr2.rocev2_bth.reserved2;
                eg_md.crc_part_6[23:0] = hdr2.rocev2_bth.packet_seq;
        }
        action update_crc_7() {
                eg_md.crc_part_7[31:31] = hdr2.rocev2_aeth.res;
                eg_md.crc_part_7[30:29] = hdr2.rocev2_aeth.opcode;
                eg_md.crc_part_7[28:24] = hdr2.rocev2_aeth.credit_count;
                eg_md.crc_part_7[23:0] = hdr2.rocev2_aeth.message_seq;
        }
        action htol_crc() {
                hdr2.rocev2_crc.crc[31:24] = eg_md.crc_final[7:0];
                hdr2.rocev2_crc.crc[23:16] = eg_md.crc_final[15:8];
                hdr2.rocev2_crc.crc[15:8] = eg_md.crc_final[23:16];
                hdr2.rocev2_crc.crc[7:0] = eg_md.crc_final[31:24];
        }

        action packet_drop(){
                eg_intr_md_for_dprsr.drop_ctl = 3w1;
        }

        apply {
                // Trying to re-calculate CRC for all NACK packets.
                if (hdr2.rocev2_aeth.isValid()) {
                        if(hdr2.rocev2_aeth.opcode == NACK_OP_CODE){
                                update_crc_12();
                                update_crc_3();
                                update_crc_4();
                                update_crc_5();
                                update_crc_6();
                                update_crc_7();
                        }
                }
                if (hdr2.rocev2_aeth.isValid()) {
                        if(hdr2.rocev2_aeth.opcode == NACK_OP_CODE){
                                eg_md.crc_final = rocev2_hash.get(
                                                {eg_md.crc_part_1,
                                                eg_md.crc_part_2,
                                                eg_md.crc_part_3,
                                                eg_md.crc_part_4,
                                                eg_md.crc_part_5,
                                                eg_md.crc_part_6,
                                                eg_md.crc_part_7});
                        }
                }
                if (hdr2.rocev2_aeth.isValid()) {
                        if(hdr2.rocev2_aeth.opcode == NACK_OP_CODE){
                                htol_crc();
                        }
                }
                if(hdr2.rocev2_bth.opcode==6||hdr2.rocev2_bth.opcode==7||hdr2.rocev2_bth.opcode==8||hdr2.rocev2_bth.opcode==10){
//                        if(eg_intr_md.egress_port==128){ // node 3
//                                if(hdr2.rocev2_bth.packet_seq==1){
//                                        bit<32>  ee;
//                                        ee = ee_count_read.execute(0);
//                                        if(ee==1){
//                                                eg_md.sess_id=15;
//                                                eg_intr_md_for_dprsr.mirror_type = 0;
//                                        }
//                                }
//                        }

                }else{
                     if(hdr2.rocev2_aeth.opcode == NACK_OP_CODE){ //NACK packet
                           ee_ts1_read.execute(0); 
                     }
                }

        }
}

Pipeline(SwitchIngressParser(),
                SwitchIngress(),
                SwitchIngressDeparser(),
                SwitchEgressParser(),
                SwitchEgress(),
                SwitchEgressDeparser()) pipe;

Switch(pipe) main;

