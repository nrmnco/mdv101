import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, First
from cocotb.queue import Queue
from shared_memory import generate_shared_memory
from BittyEmulator import BittyEmulator
#import verilated


#from vtop import Vtop
# Shared memory and instruction set
verilog_memory = generate_shared_memory(size=256)
emulator_memory = verilog_memory.copy()

# Load instructions from files
def load_instructions(em_file="instructions_for_em.txt"):
    with open(em_file, "r") as f:
        instructions_set = [int(line.strip(), 16) for line in f]
    return instructions_set

class TB:
    def __init__(self, dut, baud_rate=115200, clk_freq=50_000_000):
        self.dut = dut
        self.baud_rate = baud_rate
        self.clk_freq = clk_freq
        self.clks_per_bit = int(clk_freq / baud_rate)
        self.bit_time_ns = int(1e9 / baud_rate)  # Bit time in nanoseconds

        # Map I/O signals
        self.reset = dut.rst_n
        self.rx_data_bit = dut.ui_in_0
        self.tx_data_bit = dut.uo_out_0
        self.sel_baude_rate = dut.ui_in_2to1


        # Safely resolve MSB and LSB values
        # Reconstruct the full 13-bit value from MSB and LSB
        #self.clks_per_bit = (self.clks_per_bit_msb << 8) | self.clks_per_bit_lsb
        self.clock = dut.clk

        # Start the clock
        cocotb.start_soon(Clock(self.clock, 1e9 / clk_freq, units="ns").start())



    async def reset_dut(self):
        """Apply and release active-low reset."""
        self.reset.value = 0
        self.rx_data_bit.value = 1
        self.dut.ui_in_2to1.value = 3

        self.dut._log.info("Resetting DUT")
        await Timer(100, units="us")  # Hold reset for 100 microseconds
        self.reset.value = 1
        self.dut._log.info("DUT reset complete")

    async def send_uart_data(self, data):
        """Simulate sending a byte over UART."""
        self.rx_data_bit.value = 0  # Start bit
        self.dut._log.info("TX -> RX Start bit: 0")
        await Timer(self.bit_time_ns, units="ns")

        for i in range(8):  # Data bits (LSB first)
            bit = (data >> i) & 1
            self.rx_data_bit.value = bit
            self.dut._log.info(f"TX -> RX Bit {i}: {bit}")
            await Timer(self.bit_time_ns, units="ns")

        self.rx_data_bit.value = 1  # Stop bit
        self.dut._log.info("TX -> RX Stop bit: 1")

    async def transmit_from_tx(self):
        """Capture the UART transmission."""
        self.dut._log.info("before tx star bit")
        await FallingEdge(self.tx_data_bit)  # Wait for start bit
        await Timer(self.bit_time_ns, units="ns")
        self.dut._log.info("RX <- TX Start bit: 0")

        received_bits = []

        for i in range(8):  # Capture 8 data bits
            await Timer(self.bit_time_ns, units="ns")
            bit = int(self.tx_data_bit.value)
            received_bits.append(bit)
            self.dut._log.info(f"RX <- TX Bit {i}: {bit}")

        self.dut._log.info("RX <- TX Stop bit: 1")
        await Timer(self.bit_time_ns, units="ns")
        return sum((bit << i) for i, bit in enumerate(received_bits))

    async def wait_for_rx_done(self, timeout_us=100):
        """Wait for the RX `done` signal to go high or timeout."""
        try:
            self.dut._log.info("Waiting for RX done signal...")
            await First(RisingEdge(self.dut.user_project.uart_inst.rx_done), Timer(timeout_us, units="us"))
            self.dut._log.info("RX done signal received.")
        except TimeoutError:
            self.dut._log.info("Timeout waiting for RX done signal.")
            self.dut._log.warning("Timeout waiting for RX done signal.")

@cocotb.test()
async def uart_module_test(dut):
    """Integrated UART and instruction processing test."""
    tb = TB(dut)
    log_file = "uart_emulator_log.txt"

    # Emulator and instructions
    emulator = BittyEmulator()
    instruction_set = load_instructions()

    await tb.reset_dut()

    flag_queue = Queue()  # Queue for UART communication

    # UART receiver task (runs in parallel)
    async def uart_receiver():
        while True:
            flag_byte = await tb.transmit_from_tx()
            dut._log.info(f"Received Flag Byte: 0x{flag_byte:02X}")
            await flag_queue.put(flag_byte)
            dut._log.info("Flag byte added to queue.")

    uart_task = cocotb.start_soon(uart_receiver())

    async def process_flag(flag_byte):
        """Process UART flag."""
        dut._log.info(f"Processing Flag Byte: 0x{flag_byte:02X}")
        if flag_byte == 0x03:  # Instruction
            dut._log.info("Instruction flag received.")
            address = await flag_queue.get()
            dut._log.info(f"Address received: {address}")
            if address < len(instruction_set):
                instruction = instruction_set[address]
                dut._log.info(f"Instruction: 0x{instruction:04X}")
                await tb.send_uart_data(instruction >> 8)  # High byte
                await tb.wait_for_rx_done()
                await tb.send_uart_data(instruction & 0xFF)  # Low byte
        elif flag_byte == 0x01:  # Load
            dut._log.info("Load flag received.")
            address = await flag_queue.get()
            dut._log.info(f"Address received: {address}")
            if address < len(emulator_memory):
                data = emulator_memory[address]
                dut._log.info(f"Loaded Data: 0x{data:04X} from address 0x{address:02X}")
                await tb.send_uart_data(data >> 8)
                await tb.wait_for_rx_done()
                await tb.send_uart_data(data & 0xFF)
        elif flag_byte == 0x02:  # Store
            dut._log.info("Store flag received.")
            address = await flag_queue.get()
            dut._log.info(f"Address received: {address}")
            high_byte = await flag_queue.get()
            dut._log.info(f"High byte received: 0x{high_byte:02X}")
            low_byte = await flag_queue.get()
            dut._log.info(f"Low byte received: 0x{low_byte:02X}")
            emulator_memory[address] = (high_byte << 8) | low_byte
            dut._log.info(f"Stored 0x{emulator_memory[address]:04X} at address 0x{address:02X}")

    # Timer coroutine for the 10-minute limit
    async def timeout_timer():
        dut._log.info("10-minute timer started.")
        await Timer(10 * 60 * 1e9, units="ns")  # 10 minutes in nanoseconds
        dut._log.error("Test timeout: Exceeded 10 minutes.")
        raise TimeoutError("Test exceeded the 10-minute limit.")

    try:
        # Start the 10-minute timeout timer
        cocotb.start_soon(timeout_timer())

        pc = 0
        i = 0
        with open(log_file, "w") as log:
            while pc < len(instruction_set)-1 or pc < 255 or i < 255:
                dut._log.info("start")
                flag_byte = await flag_queue.get()
                dut._log.info("took flag")
                await process_flag(flag_byte)

                instruction = instruction_set[pc]
                format_code = instruction & 0x0003

                if format_code == 3:
                    flag_byte = await flag_queue.get()
                    dut._log.info(f"Received flag byte: {flag_byte:X}")
                    await process_flag(flag_byte)

                await FallingEdge(dut.user_project.bitty_inst.done)

                i = emulator.evaluate(i)
                pc = int(dut.user_project.pc_inst.d_out.value)

                rx_register = (instruction & 0xE000) >> 13

                try:
                    dut_rx_value = int(dut.user_project.bitty_inst.out[rx_register].value)
                except Exception as e:
                    dut_rx_value = 0
                    dut._log.warning(f"Error reading DUT RX register {rx_register}: {e}")
                
                if format_code != 2:
                    emulator_rx_value = emulator.get_register_value(rx_register)
                    if dut_rx_value == emulator_rx_value:
                        log.write(f"Instruction: {instruction:04X}, Register: {rx_register:04X}\n")
                        log.write(f"PC {pc:04X} VS em_i {i:04X}\n")
                        log.write(f"OK -> RX matches ({dut_rx_value:04X})\n\n")
                    else:
                        log.write(f"Instruction: {instruction:04X}, Register: {rx_register:04X}\n")
                        log.write(f"PC {pc:04X} VS em_i {i:04X}\n")
                        log.write(f"ERROR -> RX mismatch (DUT: {dut_rx_value:04X}, Emulator: {emulator_rx_value:04X})\n")
                        break

    except TimeoutError:
        dut._log.error("Test ended due to timeout.")

    except Exception as e:
        dut._log.error(f"Test error: {e}")

    finally:
        uart_task.kill()
