import random

class BittyInstructionGenerator:
    def __init__(self):
        pass

    def generate(self):
        count = int(input("Write number of random instructions to generate: "))
        
        try:
            with open("instructions_for_em.txt", "w") as file2:
 


                # Predefined instructions for Emulator file
                instructions_em = [
                    0xE9A1, 0x0141, 0x2141, 0x4141, 0x6141,
                    0x8141, 0xA141, 0xC141
                ]

            
                for instruction in instructions_em:
                    file2.write(f"{instruction:04x}\n")
                print(f"Predefined instructions written to Emulator file: {instructions_em}")

                # Generate and write random instructions after predefined ones
                for i in range(count):
                    instruction = random.randint(0, 0xFFFF)
                    format_code = instruction & 0x0003
                    rx = (instruction & 0xE000) >> 13

                    if format_code == 2:
                        instruction = instruction & 0xFFFC

                    # Write the random instruction to both files
                    file2.write(f"{instruction:04x}\n")
                    print(f"Generated random instruction (even index): {instruction:04x}")
                                        
                    if format_code == 0 or format_code == 1:
                        alu_sel = (instruction & 0x001C) >> 2
                        if alu_sel == 7:
                            #generate three branches after cmp with random addressses 
                            immed = random.randint(0, 255)
                            branch_instr = immed << 4
                            branch_cond = random.choice([2, 6, 10])
                            file2.write(f"{branch_instr + branch_cond:04x}\n")
                            #file2.write(f"{branch_instr + 0x6:04x}\n")
                            #file2.write(f"{branch_instr + 0xA:04x}\n")


        except IOError:
            print("Error opening instruction files")


# Instantiate and run
if __name__ == "__main__":
    generator = BittyInstructionGenerator()
    generator.generate()
