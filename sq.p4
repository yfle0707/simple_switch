#define RNR_NACK 1
#define NACK  3


/*  Ingress -------------------------------*/

control QueueInforPropogation(
        inout switch_header_t hdr2,
        inout switch_ingress_metadata_t ig_md2,
	in ingress_intrinsic_metadata_t ig_intr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md ){

    bit<2> queue_depth_flag;
    Register<bit<32>, bit<9>>(512, 0) queue_depth;
    RegisterAction<bit<32>, bit<9>, bit<2>>(queue_depth) queue_depth_write = {
        void apply(inout bit<32> value, out bit<2> read_value) {
            value = hdr2.queuedepth.content;

    }
    };
    RegisterAction<bit<32>, bit<9>, bit<2>>(queue_depth) queue_depth_read = {
        void apply(inout bit<32> value, out bit<2> read_value) {
            read_value = 0;
            if(value > 12500){  //1MB for cut_payload_action
                read_value=2;
            }else if(value > 1250){ //100KB for gen_pause
              read_value=1;
            }
        }
    };
    Register<bit<32>, bit<9>>(512,0) pause_count;
    RegisterAction<bit<32>, bit<9>, bit<32>>(pause_count) pause_count_increase = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
            //read_value = value;
        }
    };
    Register<bit<32>, bit<9>>(512,0) pfc_count;
    RegisterAction<bit<32>, bit<9>, bit<32>>(pfc_count) pfc_count_increase = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
        }
    };
    Register<bit<32>, bit<9>>(512,0) drop_pkt_count;
    RegisterAction<bit<32>, bit<9>, bit<2>>(drop_pkt_count) drop_pkt_count_increase = {
        void apply(inout bit<32> value, out bit<2> read_value) {
            value = value + 1;
            if(value[7:0]== 0xe){
                read_value = 2;
            }else{
                read_value = 0;
            }
        }
    };
    //when packet drop is decided  
    Register<bit<32>, bit<12>>(4096,26777216) drop_large_seq_register;
    RegisterAction<bit<32>, bit<12>, bit<3>>(drop_large_seq_register) drop_large_seq = {
        void apply(inout bit<32> value, out bit<3> read_value) {
            read_value=0;
            if((bit<32>)hdr2.rocev2_bth.packet_seq!=value && value != 26777216){
                read_value = 6;//drop_large_sequence
            }else{// if(value == 2677716){
                value = (bit<32>)hdr2.rocev2_bth.packet_seq; // first drop
            }
         //(bit<32>)hdr2.rocev2_bth.packet_seq==value && value != 26777216 //second drop, send cp
          //(bit<32>)hdr2.rocev2_bth.packet_seq!=value && value == 26777216  // first drop, send cp
        }
    };
    //when the packet is not going to drop  
    RegisterAction<bit<32>, bit<12>, bit<3>>(drop_large_seq_register) drop_large_seq_no_drop = {
        void apply(inout bit<32> value, out bit<3> read_value) {
            read_value=0;

            if((bit<32>)hdr2.rocev2_bth.packet_seq!=value && value != 26777216){
                read_value = 6; //drop large sequence
            }else{
                value = 26777216;
            }
            //(bit<32>)hdr2.rocev2_bth.packet_seq==value && value != 26777216 //get_retransmitted packet
            //(bit<32>)hdr2.rocev2_bth.packet_seq!=value && value == 26777216  // empty 
        }
    };

    action gen_pause_action(){ //mirror to ingress_port
	    ig_md2.sess_id= (bit<10>)ig_intr_md.ingress_port;
	    ig_md2.mirror_type = SWITCH_MIRROR_TYPE_SQ_PAUSE;
	    ig_dprsr_md.mirror_type = SWITCH_MIRROR_TYPE_PORT;
    }
    action cut_payload_action(){ //now mirror to a special port, TODO: should mirror to egress port
	    ig_dprsr_md.drop_ctl = 3w1;
	    ig_md2.sess_id=(bit<10>)(ig_tm_md.ucast_egress_port);
	    ig_md2.mirror_type = SWITCH_MIRROR_TYPE_CUT_PAYLOAD;
	    ig_dprsr_md.mirror_type = SWITCH_MIRROR_TYPE_PORT ;
        pause_count_increase.execute(ig_tm_md.ucast_egress_port); 
    }
    action nop(){
    }

    table ingress_feedback_table{
        key = {
           queue_depth_flag  : exact;
        }
        actions = {
            gen_pause_action;
	    	cut_payload_action;
            nop;
        }
        const default_action = nop;
        size = 4;
    }	

    action write_queuedepth_action(){
	    //recirculate packet for queue depth
	    queue_depth_write.execute((bit<9>)hdr2.queuedepth.index);
	    ig_tm_md.ucast_egress_port = SEED_PACKETS_RECIRCULATION_PORT;
	    ig_dprsr_md.drop_ctl = 3w0;
    }
    table write_queuedepth_table{
	    key = {
		    hdr2.queuedepth.isValid() : exact;
	    }
	    actions = {
		    nop;
			write_queuedepth_action;
	    }
	    const default_action = nop;
	    const entries = {
		    (true) : write_queuedepth_action();
		    (false) : nop();
	    }
	    size = 2;
    }	

    
    apply{
	    //Place after the egress port is decide
	    if(hdr2.rocev2_bth.isValid() && !hdr2.rocev2_aeth.isValid()){  //RoCE v2 packets
		    queue_depth_flag = queue_depth_read.execute(ig_tm_md.ucast_egress_port);
         // queue_depth_flag = drop_pkt_count_increase.execute(ig_tm_md.ucast_egress_port); 
            bit<3> drop_large_sequence_true_flag;
            if(queue_depth_flag == 2){
                  drop_large_sequence_true_flag =  drop_large_seq.execute(hdr2.rocev2_bth.dst_qp[11:0]); 
            }else{
                  drop_large_sequence_true_flag = drop_large_seq_no_drop.execute(hdr2.rocev2_bth.dst_qp[11:0]);
            }
            if(drop_large_sequence_true_flag == 6){
                ig_dprsr_md.drop_ctl = 3w1;
                 queue_depth_flag = 0;  
            }
            ingress_feedback_table.apply();
        }else if (hdr2.queuedepth.isValid()){
	    	    write_queuedepth_table.apply();
	    }else {
            if(hdr2.ethernet.ether_type == 0x8808){
                pfc_count_increase.execute(ig_tm_md.ucast_egress_port);
            }
        }
    }
}

/*  Egress -------------------------------*/
control Dcqcn(
        inout switch_header_t hdr2,
        in egress_intrinsic_metadata_t eg_intr_md){
    Register<bit<32>, bit<1>>(1, 0) ecn;
    RegisterAction<bit<32>, bit<1>, bit<32>>(ecn) ecn_mark = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            read_value=0;
            if(eg_intr_md.deq_qdepth>1250){
                read_value=6;
            
            }
        }
    };
    
    apply{
        bit<32> s3;
        s3=ecn_mark.execute(0);
        if(s3== 6){
            if(hdr2.ethernet.ether_type == 0x0800){
                hdr2.ipv4.diffserv =0b11;
            }
        }
    }

}
control IcrcCalculation(
        inout switch_header_t hdr2,
		inout switch_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md){

	Hash<bit<32>>(HashAlgorithm_t.CRC32) rocev2_hash;

	action construct_cp_pkt(){
		hdr2.rocev2_bth.opcode= ROCEV2_WRITE_REQUEST_LAST;
		hdr2.rocev2_bth.packet_seq=eg_md.next_seq;
		hdr2.ipv4.total_len = 48;
		hdr2.udp.length = 28;
	}
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
		eg_md.crc_part_5[63:48] = hdr2.udp.length;
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
	action update_crc_7() { //adding 4 bytes as the payload
		eg_md.crc_part_7 = 0;
	}
	action htol_crc() {
		hdr2.rocev2_crc.crc[31:24] = eg_md.crc_final[7:0];
		hdr2.rocev2_crc.crc[23:16] = eg_md.crc_final[15:8];
		hdr2.rocev2_crc.crc[15:8] = eg_md.crc_final[23:16];
		hdr2.rocev2_crc.crc[7:0] = eg_md.crc_final[31:24];
	}
    Register<bit<32>, bit<9>>(512,0) cp_count;
    RegisterAction<bit<32>, bit<9>, bit<32>>(cp_count) cp_count_increase = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
        }
    };

    apply{
		if(eg_md.mirror_type == SWITCH_MIRROR_TYPE_CUT_PAYLOAD ){ // for the CP packets, we currently use a special port to recirculate the data packets to cut the payload              
			//CP pkt do nothing but  
			eg_md.next_seq= hdr2.rocev2_bth.packet_seq + 1; 
			hdr2.ipv4.identification = hdr2.ipv4.identification +1;
			construct_cp_pkt();
			hdr2.left_cp.setInvalid();
			hdr2.cp_data.setValid();
			hdr2.cp_data.content=0; //xffffffff;
			update_crc_12();
			update_crc_3();
			update_crc_4();
			update_crc_5();
			update_crc_6();
			update_crc_7();
			eg_md.crc_final = rocev2_hash.get(
					{eg_md.crc_part_1,
					eg_md.crc_part_2,
					eg_md.crc_part_3,
					eg_md.crc_part_4,
					eg_md.crc_part_5,
					eg_md.crc_part_6,
					eg_md.crc_part_7});
			htol_crc();
		
        cp_count_increase.execute(eg_intr_md.egress_port);
        }    

	}
}

control QueueInfoUpdate(
        inout switch_header_t hdr2,
        in egress_intrinsic_metadata_t eg_intr_md){
    
        Register<bit<32>, bit<9>>(512, 0) queue_depth;
        RegisterAction<bit<32>, bit<9>, bit<32>>(queue_depth) queue_depth_write = {
            void apply(inout bit<32> value, out bit<32> read_value) {
                value = (bit<32>)eg_intr_md.deq_qdepth;
            }
        };
        RegisterAction<bit<32>, bit<9>, bit<32>>(queue_depth) queue_depth_read = {
            void apply(inout bit<32> value, out bit<32> read_value) {
                read_value = value;
            }
        };

        Register<bit<32>, bit<12>>(4096,0) seedpkt_count;
        RegisterAction<bit<32>, bit<12>, bit<32>>(seedpkt_count) seedpkt_count_read = {
            void apply(inout bit<32> value, out bit<32> read_value) {
                value = value + 1;
                read_value = value;
            }
        };


apply{
		if(eg_intr_md.egress_port == SEED_PACKETS_RECIRCULATION_PORT){
            //seedpkt_count_read.execute(0);
            hdr2.queuedepth.content = queue_depth_read.execute((bit<9>)hdr2.queuedepth.index);
		}else{
			queue_depth_write.execute(eg_intr_md.egress_port);
		}
	}

}

control GenSQPause(
		inout switch_header_t hdr2,
		inout switch_egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md){
	action gen_pause(){
		hdr2.ipv4.setInvalid();
		hdr2.udp.setInvalid();
		hdr2.rocev2_aeth.setInvalid();
		hdr2.rocev2_bth.setInvalid();
		hdr2.rocev2_reth.setInvalid();
		hdr2.left.setInvalid();
		//hdr2.rocev2_payload_for_mirror_ex.setInvalid();
		//hdr2.rocev2_crc.setInvalid();
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
		hdr2.pfc.cev = 0x0001;//for priority 0
		hdr2.pfc.time0 = 0xDAC; //0xDAC; //30D4;//0x4E2;//3E8;//0x4E2;//1250 unit  each unit is 512bit time
		hdr2.pfc.time1 = 0;
		hdr2.pfc.time2 = 0;
		hdr2.pfc.time3 = 0;
		hdr2.pfc.time4 = 0;
		hdr2.pfc.time5 = 0;
		hdr2.pfc.time6 = 0;
		hdr2.pfc.time7 = 0;
		hdr2.pfc.pad = 0;
	}
    Register<bit<32>, bit<9>>(512,0) pause_count;
    RegisterAction<bit<32>, bit<9>, bit<32>>(pause_count) pause_count_increase = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
            //read_value = value;
        }
    };
    Register<bit<32>, bit<9>>(512,0) pfc_count;
    RegisterAction<bit<32>, bit<9>, bit<32>>(pfc_count) pfc_count_increase = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = value + 1;
            //read_value = value;
        }
    };

    apply{
        if(hdr2.ethernet.ether_type == 0x8808){
            pfc_count_increase.execute(eg_intr_md.egress_port);
        }

        if(eg_md.mirror_type == SWITCH_MIRROR_TYPE_SQ_PAUSE){
			gen_pause();
            pause_count_increase.execute(eg_intr_md.egress_port);
		}
	}
}


