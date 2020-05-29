#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>  // For uint64_t
#include <inttypes.h> // For properly printing uint64_t

#include <bf_types/bf_types.h>
#include <pd_common.h>
#include <pd_conn_mgr.h>
//#include <pd/pd.h>  // contains PD APIs for the P4 program
#include <port_mgr/bf_port_if.h> // for the 1588 tx ts API call

/* Simple initialization APIs */
#include <bf_switchd/bf_switchd.h>
#include <traffic_mgr/traffic_mgr_ppg_intf.h>
#include <traffic_mgr/traffic_mgr_port_intf.h>
#include <traffic_mgr/traffic_mgr_types.h>
#include <traffic_mgr/traffic_mgr_q_intf.h>
#include <traffic_mgr/traffic_mgr_sch_intf.h>
#include <tofino/bf_pal/bf_pal_port_intf.h>

/* 
 * Convenient defines that reflect SDE conventions
 */
#ifndef SDE_INSTALL
#error "Please add -DSDE_INSTALL=\"$SDE_INSTALL\" to CPPFLAGS"
#endif

#define CONF_FILE_DIR        "share/p4/targets/tofino"
#define CONF_FILE_PATH(prog) \
    SDE_INSTALL "/" CONF_FILE_DIR "/" prog ".conf"

#define STATUS_SERVER_TCP_PORT 7777


#define P4_PROG_NAME "yle_simple_switch"
#define TX_CAPTURE_DEV_PORT 128

// Global variable(s)
bf_switchd_context_t  *switchd_ctx;


void init_bf_switchd() {
	p4_pd_status_t status;

	/* Check that we are running as root */
    if (geteuid() != 0) {
        printf("ERROR: This program must be run as root\n");
        exit(1);
    }

    /* Allocate memory to hold switchd configuration and state */
    switchd_ctx = calloc(1, sizeof(bf_switchd_context_t));

    if(switchd_ctx == NULL){
    	printf("ERROR: Couldn't allocate memory for switchd_ctx\n");
    	exit(1);
    }

    /* Define the switchd configuration */
    switchd_ctx->install_dir = SDE_INSTALL;
    switchd_ctx->conf_file = CONF_FILE_PATH(P4_PROG_NAME);
    switchd_ctx->skip_p4 = false;
    switchd_ctx->running_in_background = true;
    switchd_ctx->dev_sts_port = STATUS_SERVER_TCP_PORT;
    switchd_ctx->dev_sts_thread = true;

    printf("#######   Initializing switchd   #######\n\n");
    status = bf_switchd_lib_init(switchd_ctx);

    if(status == BF_SUCCESS)
    	printf("\n\nSUCCESS: switchd initialized successfully\n\n");
    else{
    	printf("ERROR initializing switchd:\n%s\n", bf_err_str(status));
    	exit(1);
    }


}


void status_check(bf_status_t status,  const char * funcname){
        if(status == BF_SUCCESS)
                printf("SUCCESS: function %s\n", funcname);
        else{
                printf("ERROR: Client failed function %s, err: %s\n", funcname, bf_err_str(status));
                exit(-1);
        }
}

p4_pd_status_t control_plane_app(){

	bf_status_t      status;
	p4_pd_sess_hdl_t    sess_hdl;
	const uint8_t dev_id = 0;

	printf("\n#######   Running the CP application   #######\n\n");

	status = p4_pd_client_init(&sess_hdl);

    status_check(status, "p4_pd_client_init");
	// Initialize ports and tables using bfshell commands
	system("bfshell -f ./portadd.py"); // this is a shortcut ;)
	system("bfshell -b ./setup.py"); // this is a shortcut ;)
    printf("\n\nDONE adding bfrt_python commands!\n\n\n");

    sleep(5); // just wait for the ports to come up. Can do better using port OPR checks.

    
    bf_dev_port_t ports[8] = {128, 136, 144};  //1/0,2/0,3/0 
    for(int i=0; i<3; i++){
        bf_dev_port_t ingress_port = ports[i];
        bf_dev_port_t egress_port = ports[i];

        bf_tm_ppg_hdl ppg;
        status = bf_tm_ppg_allocate(dev_id, ingress_port, &ppg);
        status_check(status, "bf_tm_ppg_allocate");

        uint32_t cells = 200; //16K
        status = bf_tm_ppg_guaranteed_min_limit_set(dev_id,ppg, cells);
        status_check(status, "bf_tm_ppg_guaranteed_min_limit_set");

        uint8_t icos_bmap = 0x1;
        status = bf_tm_ppg_icos_mapping_set(dev_id, ppg, icos_bmap);
        status_check(status, "bf_tm_ppg_icos_mapping_set");

        uint32_t skid_cells = 4000;
        status = bf_tm_ppg_skid_limit_set(dev_id, ppg, skid_cells);
        status_check(status, "bf_tm_ppg_skid_limit_set");

        status = bf_tm_ppg_lossless_treatment_enable(dev_id, ppg);
        status_check(status, "bf_tm_ppg_lossless_treatment_enable");

        status =  bf_tm_port_flowcontrol_mode_set(dev_id, ingress_port, BF_TM_PAUSE_PFC);
        status_check(status, "bf_tm_port_flowcontrol_mode_set");

        uint8_t cos_to_icos[8] = {0,1,2,3,4,5,6,7}; //index is cos, value is icos.
        status = bf_tm_port_pfc_cos_mapping_set(dev_id, ingress_port, cos_to_icos);
        status_check(status, "bf_tm_port_pfc_cos_mapping_set");

        //bf_tm_q_guaranteed_min_limit_set
        //configure static queue 
        bf_tm_queue_t queue_id = 0;
        uint32_t base_use_limit_cells = 12500; //1MB
        status = bf_tm_q_app_pool_usage_set(dev_id, egress_port, queue_id, BF_TM_EG_APP_POOL_3,base_use_limit_cells, BF_TM_Q_BAF_DISABLE, base_use_limit_cells/2 );
        status_check(status, "bf_tm_q_app_pool_usage_set");

        uint32_t burst_size = 1500; //in bytesi
        uint32_t rate = 80000000; //in kbps
 //       status = bf_tm_sched_port_shaping_rate_set(dev_id, egress_port, false, burst_size, rate);
 //       status_check(status, "bf_tm_sched_port_shaping_rate_set");
 //       status = bf_tm_sched_port_shaping_enable(dev_id, egress_port);
 //       status_check(status, "bf_tm_sched_port_shaping_enable");
        uint8_t cos_map = 0x0;
        status = bf_tm_q_pfc_cos_mapping_set(dev_id, egress_port, queue_id, cos_map ); 
        status_check(status, "bf_tm_q_pfc_cos_mapping_set");

        status = bf_tm_port_flowcontrol_rx_set(dev_id, egress_port, BF_TM_PAUSE_PFC);
        status_check(status, "bf_tm_port_flowcontrol_rx_set");

        status = bf_pal_port_flow_control_pfc_set(dev_id, egress_port, 0xfffffff, 0xffffffff);
        status_check(status,"egress bf_pal_port_flow_control_pfc_set");

    }

    while(true){
            printf("Starting...\n");
            sleep(10); 
    }

    return BF_SUCCESS;

}


int main(int argc, char const *argv[]) {

	/* Initialize switchd */
	init_bf_switchd();


	/* Run the control plane application */
	control_plane_app(); // MUST implement an infinite while loop


	/* Clean up */
	if (switchd_ctx)
		free(switchd_ctx);


	return 0;

}

