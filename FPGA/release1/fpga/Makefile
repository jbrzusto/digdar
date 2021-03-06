#
# $Id: Makefile 1026 2014-02-07 09:54:51Z matej.oblak $
#
# Red Pitaya Makefile for building ZYNQ PL and PS binary
#
# Produces:
#   1. FPGA bit file & XSDC configuration.
#   2. XSDK products.
#   3. Booting image & device-tree.
#   4. installs image as /opt/boot.bin.digdar and a copy as /opt/boot.bin
#      on an attached rp, using ssh to root@rp


.PHONY: all clean image

#### Parameters
# vivado or ahead
FPGA_TOOL=vivado

SDK_DIR=$(FPGA_TOOL)/red_pitaya.sdk/SDK/SDK_Export


#### Cover task
all: fpga sw_package image
	echo ' \n'

install: image
	ssh root@rp rw
	scp image/out/boot.bin root@rp:/opt/boot.bin.digdar
	ssh root@rp "cp -f /opt/boot.bin.digdar /opt/boot.bin; ro"

#### CLEAN
clean:
ifeq ($(FPGA_TOOL),ahead)
	planAhead -mode tcl -source $$PWD/run_planahead.tcl -tclargs clean
endif
ifeq ($(FPGA_TOOL),vivado)
	vivado -mode tcl -source $$PWD/run_vivado.tcl -tclargs clean
endif
	make -C $(SDK_DIR)/fsbl_bsp/ clean
	make -C $(SDK_DIR)/fsbl/Debug/ clean
	make -C $(SDK_DIR)/device-tree_bsp_0/ clean
	make -C $(SDK_DIR)/uboot_bsp_0/ clean
	make -C image/ FPGA_TOOL=$(FPGA_TOOL) -k clean


#### Prepare images
image:
	make -C image/ FPGA_TOOL=$(FPGA_TOOL) -k all


#### Build SDK projects
sw_package: hw_src_copy fsbl_bsp fsbl devicetree uboot

hw_src_copy:
ifeq ($(FPGA_TOOL),vivado)
	sed -i 's/C_SDIO_CLK_FREQ_HZ\"\ VALUE=\"50000000/C_SDIO_CLK_FREQ_HZ\"\ VALUE=\"125000000/' $(SDK_DIR)/hw/system.xml
endif
	cp $(SDK_DIR)/hw/ps7_init.*    $(SDK_DIR)/fsbl/src/ 

uboot:
	make -C $(SDK_DIR)/uboot_bsp_0/ -k all

devicetree:
	make -C $(SDK_DIR)/device-tree_bsp_0/ -k all

fsbl:
	make -C $(SDK_DIR)/fsbl/Debug/ -k all

fsbl_bsp:
	make -C $(SDK_DIR)/fsbl_bsp/ -k all


#### Run FPGA tool
fpga:
ifeq ($(FPGA_TOOL),ahead)
	planAhead -mode tcl -source $$PWD/run_planahead.tcl -tclargs build
endif
ifeq ($(FPGA_TOOL),vivado)
	vivado -mode tcl -source $$PWD/run_vivado.tcl -tclargs build
endif




