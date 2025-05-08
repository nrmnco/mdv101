![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

- [Read the documentation for project](docs/info.md)

# Table of Contents

1. [Getting Started](#getting-started)  
2. [Environment Setup](#environment-setup)  
3. [Preparing User Modules to Work with the System](#preparing-user-modules-to-work-with-the-system)  
4. [Load Store Unit (LSU) Implementation Guide](#load-store-unit-lsu-implementation-guide)  
5. [Fetch Instruction Unit (FIU)](#fetch-instruction-unit-fiu)  
6. [Top Module](#top-module)  
7. [How to test the system](#how-to-test-the-system)  

---

# Bitty Processor Integration Guide

## Overview

This repository provides a framework for integrating and testing the **Bitty Processor** and related modules. Follow the instructions below to set up your environment, prepare your modules, and ensure compatibility with the provided system.

---

## Getting Started

### Step 1: Use This Repository as a Template

1. Navigate to this GitHub repository.
2. Click the **Use this template** button to create a new repository.
3. Clone the newly created repository:
   ```bash
   git clone <your-repository-url>
   ```
   Replace `<your-repository-url>` with the actual URL of your repository.

---

## Environment Setup

Ensure you are working in **Ubuntu** or **Windows Subsystem for Linux (WSL)** before proceeding.

### Install Dependencies

1. Install **Verilator** and **Icarus Verilog**:
   ```bash
   sudo apt-get install verilator iverilog
   ```
2. Install Python and Pip:
   ```bash
   sudo apt-get install python3 python3-pip
   ```
3. Install Python requirements:
   ```bash
   pip install -r requirements.txt
   ```

### Organize Files

- Move the **Bitty Processor** top module and all related modules (**ALU**, **Control Unit**, etc.) into the `src` directory.

---

## Preparing User Modules to Work with the System

### Naming Conventions

1. Ensure the names of your modules match the examples provided below.  
   If your module names differ, update the top-module accordingly.

### Top-Module Code

- The default top-module design can be found in **`bitty-tt-template/src/project_final.v`**.  
- You may:
  - Add intermediate states to the FSM if additional delays are required.
  - Rename the top-module from `tt_um_bitty` to a name of your choice.

Here’s a sample of the provided **top-module** code:

```verilog
module tt_um_bitty (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (0=input, 1=output)
    input  wire       ena,      // Enable signal
    input  wire       clk,      // Clock signal
    input  wire       rst_n     // Active-low reset
);

// Implementation details ...
  branch_logic bl_inst();
  pc pc_inst();
  bitty bitty_inst();

endmodule
```

---

### Expected I/O Port Names for User Modules

#### 1. **Bitty Processor**  
Your `bitty` module must implement the following ports:

```verilog
module bitty(
    input run, // Activate Bitty (high to enable)
    input clk,
    input reset, // Active-low reset
    input [15:0] d_instr, // Instruction input
    output [15:0] d_out, // ALU output
    output done, // High when instruction is executed
    
    // UART communication ports
    input [7:0] rx_data,
    input rx_done,
    input tx_done,
    output tx_en,
    output [7:0] tx_data
);
```

#### 2. **Program Counter (PC)**  
Your `pc` module must implement the following ports:

```verilog
module pc(
    input clk,
    input en_pc, // Enable PC
    input reset, // Active-low reset
    input [7:0] d_in, // Input memory address
    output reg [7:0] d_out // Output memory address
);
```

#### 3. **Branch Logic**  
Your `branch_logic` module must implement the following ports:  
⚠️ **Do not remove Verilator-related comments!**

```verilog
module branch_logic (
    input [7:0] address,
    /* verilator lint_off UNUSED */
    input [15:0] instruction,
    input [15:0] last_alu_result,
    output reg [7:0] new_pc // Updated program counter
);
```

---

## Load Store Unit (LSU) Implementation Guide

### Overview of the LSU
The Load Store Unit (LSU) handles memory operations by interacting with the UART module and managing data transfers to/from memory.

### Example I/O Ports for LSU

```verilog
module lsu(
    // General ports
    input wire clk,
    input wire reset, // Active-low reset
    output done_out, // Signal indicating the operation is complete

    // Design preferences
    input [1:0] en_ls, // Load/Store control
    input wire [7:0] address, // 8-bit address to be sent
    input [15:0] data_to_store,
    output [15:0] data_to_load, // 16-bit instruction received

    // Ports for UART module
    input wire rx_do, // Signal indicating data received
    input wire [7:0] rx_data, // Data received from UART
    input wire tx_done, // Signal indicating transmission is done
    output tx_start_out, // Signal to start UART transmission -> low active
    output [7:0] tx_data_out // Data to be transmitted over UART
);
```

### Notes for Implementation

1. **Finite State Machine**: You can use Fetch Instruction Unit's FSM as an example to build one for LSU. The code can be found in src/fetch_instruction.v directory. The explanation is provided below.
2. **Operation Flags**: In provided example `en_ls` is used to control the load-store operation by Control Unit:
   - `00`: Idle
   - `01`: Load
   - `10`: Store
   - `11`: Reserved
3. **Testing**: Use the provided testbench `bitty-tt-template/test/new_tb.py` to validate LSU functionality.

---

## Fetch Instruction Unit (FIU)

### Overview
The Fetch Instruction Unit (FIU) manages the process of retrieving 16-bit instructions over UART. It sequentially sends a flag byte, an address byte, and receives two bytes (high and low) of the instruction.

### FIU Code Explanation

#### Key Features
- **Inputs**:
  - `clk` and `reset`: Clock and reset signals.
  - `address`: Memory address for instruction fetch.
  - `rx_do`, `rx_data`, `tx_done`: UART communication signals.
  - `stop_for_rw`: Pause FIU during UART operations.
- **Outputs**:
  - `instruction_out`: Fetched 16-bit instruction.
  - `tx_start_out`, `tx_data_out`: UART transmission control signals.
  - `done_out`: Indicates fetch completion.

#### FSM Workflow
1. **IDLE**: Initialize and wait for start signal.
2. **SEND_FLAG**: Transmit the operation flag (`0x03`).
3. **SEND_ADDR**: Transmit the 8-bit address.
4. **RECEIVE_INST_HIGH**: Receive the high byte of the instruction.
5. **RECEIVE_INST_LOW**: Receive the low byte of the instruction.
6. **DONE**: Signal operation completion.

---

## Notes

- Ensure all modules conform to the I/O specifications provided above.
- Verilator lint comments (`/* verilator lint_off ... */`) are essential for simulation. Do not delete them.
- Adjust FSM logic in the top-module if additional delays or states are required for your design.
- Familiarize yourself with the RTL files and test your system thoroughly using the provided environment and tools.
---

## **UART MODULE**
### File: `uart_module.v`

#### **Purpose of Each Port:**
- **clk**: System clock signal for synchronizing the UART operations.
- **rst**: Reset signal to initialize the UART module.
- **clks_per_bit**: Determines the number of clock cycles per UART bit, calculated as `clk_rate/baud_rate`. For example, with a 50MHz clock and 9600 baud rate, `clks_per_bit = 50,000,000 / 9600 ≈ 5208`.
- **rx_data_bit**: Serial input for receiving data bits from external devices.
- **rx_done**: Indicates when a complete byte has been received.
- **tx_data_bit**: Serial output for transmitting data bits to external devices.
- **data_tx**: Parallel data to be transmitted (input).
- **tx_en**: Enable signal to initiate data transmission.
- **tx_done**: Indicates when the transmission of a byte is complete.
- **recieved_data**: Parallel output containing the received byte.

---

## **Multiplexer Module**
### File: `mux2to1.v`

This is a simple 2-to-1 multiplexer that selects one of two inputs based on a control signal (`sel`).

---

## **Top Module**

![396090847-89a714ac-a5bf-4ce8-848c-53a10e8f25c2](https://github.com/user-attachments/assets/74fc2865-f0b7-45e8-8a6f-d8512c8b2c74)

### File: `project_final.v`

#### **Purpose:**
The top module integrates the **Bitty Processor**, UART, program counter, and branch logic. It manages data flow and control signals for the entire system.

---

### **Key Functional Blocks Explained:**

1. **Input/Output (I/O) Ports:**
   - **`ui_in`**: Dedicated input signals, e.g., `rx_data_bit` and `sel_baude_rate`.
   - **`uo_out`**: Dedicated output signals, e.g., `tx_data_bit`.
   - **`uio_in`, `uio_out`, `uio_oe`**: General-purpose I/O for flexible configuration.

2. **UART Integration:**
   - Configures baud rate dynamically based on `sel_baude_rate`.
   - Handles data transmission (`tx_data_bit`) and reception (`rx_data_bit`) through the **UART module**.

3. **Fetch Instruction Module:**
   - Fetches instructions from memory and transmits data to external systems via UART.
   - Handles instruction decoding and communication with the UART module.


---

### **FSM (Finite State Machine):**
Manages the overall flow of operations with the following states:
- **S0**: Idle state, waiting for an instruction fetch to complete (`fetch_done`).
- **S1**: Transition state after instruction fetch.
- **S2**: Program counter update.
- **S3**: Decoding specific instructions (`mem_out[1:0]`).
- **S4/S5**: Instruction execution and computation.
- **S6**: Waits for the Bitty processor to complete its task (`done`).
- **S7**: Prepares data for UART transmission.

---

### **Key Signals:**
- **`stop_for_rw`**: Pauses system operation during data read/write.
- **`uart_sel`**: Selects the UART data source (fetch module or Bitty processor).
- **`tx_en`, `tx_data`**: Enable and data signals for UART transmission.

---

### **1. `tb.v`**

This Verilog file serves as a simple testbench for the `tt_um_bitty` module. It provides a simulation environment to test the functionality of the module.

#### **Key Points:**

1. **Simulation Configuration:**
   - The `initial` block sets up signal dumping to a VCD file, which can be viewed in GTKWave for waveform analysis.  
     ```verilog
     initial begin
       $dumpfile("tb.vcd");
       $dumpvars(0, tb);
     end
     ```

2. **Testbench Signals:**
   - Declares necessary signals (`clk`, `rst_n`, `ena`, `uio_in`, etc.) used to drive and observe the module under test (MUT).  
   - Signals are mapped directly to the DUT (Device Under Test) ports.

3. **Module Instantiation:**
   - Instantiates the `tt_um_bitty` module (your DUT) and connects it to the testbench signals.  
   - Includes power signals (`VPWR` and `VGND`) for gate-level testing when the `GL_TEST` flag is defined.

4. **I/O Mapping:**
   - Inputs (`uio_in`, `ui_in`) and outputs (`uo_out`, `uio_out`) are connected to the respective ports of the DUT.
   - The `ena`, `clk`, and `rst_n` signals are used to enable, clock, and reset the module during simulation.

This testbench serves as the skeleton where specific input patterns and stimulus are typically provided by an external cocotb Python script.

---

### **2. `new_tb.v`**

This is the corresponding cocotb-based Python testbench file. It provides a more sophisticated simulation setup, leveraging cocotb's features for driving and monitoring the DUT.

#### **Key Points:**

1. **DUT Ports:**
   - Maps the DUT signals to Python attributes for ease of interaction:  
     ```python
     self.reset = dut.rst_n
     self.rx_data_bit = dut.ui_in_0
     self.tx_data_bit = dut.uo_out_0
     self.sel_baude_rate = dut.ui_in_2to1
     ```
   - The `reset` signal is active-low, meaning it resets the DUT when set to `0`.

2. **Resetting the DUT:**
   - The `reset_dut` method applies and releases the active-low reset while ensuring the initial conditions for other signals:  
     ```python
     async def reset_dut(self):
         self.reset.value = 0
         self.rx_data_bit.value = 1
         self.dut.ui_in_2to1.value = 3
         await Timer(100, units="us")
         self.reset.value = 1
     ```

3. **UART Simulation:**
   - Implements UART communication, including transmitting (`send_uart_data`) and receiving (`transmit_from_tx`) bytes over the `rx_data_bit` and `tx_data_bit` lines.  

4. **Shared Memory and Instructions:**
   - Uses shared memory (`verilog_memory`) to synchronize data between the Verilog DUT and an emulator.
   - Loads an instruction set from a file (`load_instructions`) to simulate processor operations.

5. **Flag Processing:**
   - Processes different flags (`0x01` for Load, `0x02` for Store, `0x03` for Instruction) received over UART to perform memory and instruction operations.

6. **Timeout Handling:**
   - Implements a 10-minute timeout for the test to prevent indefinite execution:  
     ```python
     async def timeout_timer():
         await Timer(10 * 60 * 1e9, units="ns")  # 10 minutes in nanoseconds
         raise TimeoutError("Test exceeded the 10-minute limit.")
     ```

7. **End-to-End Testing:**
   - Validates the DUT's functionality by comparing its behavior with an emulator (`BittyEmulator`) at each step.
   - Logs results for every instruction and detects mismatches between the DUT and emulator.

---

### **How to test the system**

#### **1. Preparing Instructions**
You can create or modify the machine code or assembly instructions based on your testing requirements.

**Option 1: Automatic Machine Code Generation**
- Use `CIG_run.py`:
  ```bash
  python3 CIG_run.py
  ```
  - This script generates `output.txt`, which contains machine code representing predefined assembly instructions.

**Option 2: Writing Custom Instructions**
- Manually create or modify the `output.txt` file.
- Include your specific assembly instructions for custom testing.

---

#### **2. Disassembling Machine Code**
- Convert machine code (`output.txt`) into assembly instructions (`instructions_for_em.txt`) using `er_tool`:
  ```bash
  ./er_tool -d -i output.txt -o instructions_for_em.txt
  ```
  - This ensures the assembly code (`instructions_for_em.txt`) is available for the testbench.

---

#### **3. Running the Testbench**
- Navigate to the test directory:
  ```bash
  cd ~/bitty-tt-template/test
  ```
- Execute the testbench using `make`:
  ```bash
  make
  ```
  - The testbench:
    - Loads `instructions_for_em.txt`.
    - Simulates UART communication for instruction execution.
    - Compares the outputs of the Device Under Test (DUT) with the expected results.
    - Logs the results in `uart_emulator_log.txt`.

---

#### **4. Additional Utilities**
- **Assembling Assembly Code:**
  If you need to create machine code from `instructions_for_em.txt`:
  ```bash
  ./er_tool -a -i instructions_for_em.txt -o output.txt
  ```

- **Disassembling Machine Code:**
  To verify or modify `output.txt` back into assembly:
  ```bash
  ./er_tool -d -i output.txt -o instructions_for_em.txt
  ```

---

### **Testbench Features**

1. **Simulated UART Communication:**
   - UART signals are generated.
   - DUT transmissions are captured for validation.

2. **Instruction Execution:**
   - Instructions are fetched from `instructions_for_em.txt`.
   - Execution is simulated in real-time.

3. **State Validation:**
   - DUT outputs are compared to expected results.
   - Any discrepancies are logged in `uart_emulator_log.txt`.

4. **Error Reporting:**
   - Logs mismatches or issues for debugging.

---

### **Practical Example**

1. **Generate Machine Code:**
   ```bash
   python3 CIG_run.py
   ```

2. **Disassemble Code:**
   ```bash
   ./er_tool -d -i output.txt -o instructions_for_em.txt
   ```

3. **Run the Testbench:**
   ```bash
   cd ~/bitty-tt-template/test
   make
   ```

4. **Check Logs:**
   - Inspect `uart_emulator_log.txt` for results:
     - Successes and failures.
     - Register values.
     - Any detected mismatches.

---

## Set up your Verilog project for TinyTapeout

1. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
2. Edit [docs/info.md](docs/info.md) and add a description of your project.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
