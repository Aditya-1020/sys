import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import secrets

ADDR_WIDTH = 8
DATA_WIDTH = 32

ADDR_LSB = 2
IDX_CTRL, IDX_STATUS, IDX_IRQ_EN, IDX_IRQ_STAT = 0, 1, 2, 3

def rand_word():
	return secrets.randbits(DATA_WIDTH)

def addr_of(idx):
	return idx << ADDR_LSB

async def start_clock(dut, period_ns=10):
	cocotb.start_soon(Clock(dut.aclk, period_ns, units='ns').start())

async def reset_dut(dut, cycles=5):
	dut.aresetn.value = 0
	dut.i_s_axil_awaddr.value = 0
	dut.i_s_axil_awprot.value = 0
	dut.i_s_axil_awvalid.value = 0
	dut.i_s_axil_wdata.value = 0
	dut.i_s_axil_wstrb.value = 0
	dut.i_s_axil_wvalid.value = 0
	dut.i_s_axil_bready.value = 0
	dut.i_s_axil_araddr.value = 0
	dut.i_s_axil_arprot.value = 0
	dut.i_s_axil_arvalid.value = 0
	dut.i_s_axil_rready.value = 0
	dut.csr_status.value = 0
	dut.csr_irq_set.value = 0
	for _ in range(cycles):
		await RisingEdge(dut.aclk)
	dut.aresetn.value = 1
	await RisingEdge(dut.aclk)

async def axil_write(dut, addr, data, strb=0xF, timeout=50):
	# drive single axil write, aw and w accepted independently
	dut.i_s_axil_awaddr.value = addr
	dut.i_s_axil_awvalid.value = 1
	dut.i_s_axil_wdata.value = data
	dut.i_s_axil_wstrb.value = strb
	dut.i_s_axil_wvalid.value = 1
	dut.i_s_axil_bready.value = 1

	aw_done = w_done = False
	for _ in range(timeout):
		await RisingEdge(dut.aclk)
		if not aw_done and dut.o_s_axil_awready.value:
			dut.i_s_axil_awvalid.value = 0
			aw_done = True
		if not w_done and dut.o_s_axil_wready.value:
			dut.i_s_axil_wvalid.value = 0
			w_done = True
		if aw_done and w_done:
			break
	else:
		raise TimeoutError("wr address/data phase never completed")

	for _ in range(timeout):
		await RisingEdge(dut.aclk)
		if dut.o_s_axil_bvalid.value:
			break
	else:
		raise TimeoutError("wr response BVALID never arrived")

	resp = int(dut.o_s_axil_bresp.value)
	dut.i_s_axil_bready.value = 0
	return resp

async def axil_read(dut, addr, timeout=50):
	dut.i_s_axil_araddr.value = addr
	dut.i_s_axil_arvalid.value = 1
	dut.i_s_axil_rready.value = 1

	for _ in range(timeout):
		await RisingEdge(dut.aclk)
		if dut.o_s_axil_arready.value:
			dut.i_s_axil_arvalid.value = 0
			break
	else:
		raise TimeoutError("arready never asserted")

	for _ in range(timeout):
		await RisingEdge(dut.aclk)
		if dut.o_s_axil_rvalid.value:
			break
	else:
		raise TimeoutError("read data phase rvalid never arrived")

	data = int(dut.o_s_axil_rdata.value)
	resp = int(dut.o_s_axil_rresp.value)
	dut.i_s_axil_rready.value = 0
	return data, resp

@cocotb.test()
async def test_reset_values(dut):
	await start_clock(dut)
	await reset_dut(dut)

	data, resp = await axil_read(dut, addr_of(IDX_CTRL))
	assert data == 0, f"CTRL not 0 after reset, got {data:#x}"
	assert resp == 0, f"Unexpected rresp {resp}"

	data, _ = await axil_read(dut, addr_of(IDX_IRQ_EN))
	assert data == 0, f"IRQ_EN not 0 after reset, got {data:#x}"

@cocotb.test()
async def test_ctrl_write_read(dut):
	await start_clock(dut)
	await reset_dut(dut)

	input_k = rand_word()
	resp = await axil_write(dut, addr_of(IDX_CTRL), input_k)
	assert resp == 0, f"Unexpected BRESP {resp}"

	data, _ = await axil_read(dut, addr_of(IDX_CTRL))
	assert data == input_k, f"CTRL readback mismatch: {data:#x} != {input_k:#x}"

@cocotb.test()
async def test_irq_en_write_read(dut):
	await start_clock(dut)
	await reset_dut(dut)

	await axil_write(dut, addr_of(IDX_IRQ_EN), 0x0000_00FF)
	data, _ = await axil_read(dut, addr_of(IDX_IRQ_EN))
	assert data == 0xFF, f"IRQ_EN readback mismatch: {data:#x}"

@cocotb.test()
async def test_wstrb_partial_write(dut):
	await start_clock(dut)
	await reset_dut(dut)

	await axil_write(dut, addr_of(IDX_CTRL), 0x1122_3344, strb=0xF)
	await axil_write(dut, addr_of(IDX_CTRL), 0x0000_00AA, strb=0x1)

	data, _ = await axil_read(dut, addr_of(IDX_CTRL))
	assert data == 0x1122_33AA, f"partial write mismatch: {data:#x}"


@cocotb.test()
async def test_status_is_read_only(dut):
	"""STATUS reflects the csr_status input and is not writable via AXI."""
	await start_clock(dut)
	await reset_dut(dut)

	dut.csr_status.value = 0xCAFEF00D
	await RisingEdge(dut.aclk)

	data, _ = await axil_read(dut, addr_of(IDX_STATUS))
	assert data == 0xCAFEF00D, f"STATUS mismatch: {data:#x}"

	await axil_write(dut, addr_of(IDX_STATUS), 0x1234_5678)
	dut.csr_status.value = 0x1111_2222
	await RisingEdge(dut.aclk)
	data, _ = await axil_read(dut, addr_of(IDX_STATUS))
	assert data == 0x1111_2222, "STATUS should track csr_status, not the AXI write"


@cocotb.test()
async def test_irq_stat_set_and_clear(dut):
	await start_clock(dut)
	await reset_dut(dut)

	dut.csr_irq_set.value = 0x0000_0001
	await RisingEdge(dut.aclk)
	await RisingEdge(dut.aclk)

	data, _ = await axil_read(dut, addr_of(IDX_IRQ_STAT))
	assert data & 0x1, f"IRQ_STAT bit 0 not set: {data:#x}"

	dut.csr_irq_set.value = 0
	await axil_write(dut, addr_of(IDX_IRQ_STAT), 0x0000_0001)  # write-1-to-clear

	data, _ = await axil_read(dut, addr_of(IDX_IRQ_STAT))
	assert (data & 0x1) == 0, f"IRQ_STAT bit 0 not cleared: {data:#x}"