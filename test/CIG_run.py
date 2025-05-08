from cocotb_instr_gen import BittyInstructionGenerator

def load_instructions(em_file="instructions_for_em.txt"):
    instructions_fpga = [0x0000] * 256  # Initialize with zeros

# Print instructions_fpga to verify the result
    for index, instruction in enumerate(instructions_fpga):
        print(f"{index:02X}: {instruction:04X}")


        with open(em_file, "r") as f:
            instructions_em = [int(line.strip(), 16) for line in f]

        print("Emulator Instructions Read:")
        for instr in instructions_em:
            print(f"{instr:04X}")

        return instructions_fpga, instructions_em

# Run the generator to write the instructions
generator = BittyInstructionGenerator()
generator.generate()

# Read the instructions back to confirm
instructions_fpga, instructions_em = load_instructions()

print("\nFinal Emulator Instructions:")
for instr in instructions_em:
    print(f"{instr:04X}")
