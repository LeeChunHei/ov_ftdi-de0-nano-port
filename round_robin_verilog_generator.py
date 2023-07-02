import argparse

def rr_verilog_gen(n, switch_policy, out_filename):
    min_bit_to_store = n.bit_length()
    with open(out_filename, 'w') as out:
        out.write(f"module round_robin_{n}req(\n")
        out.write("    input       clk,\n")
        out.write("    input       rst_n,\n")
        for i in range(n):
            out.write(f"    input       request{i},\n")
        out.write(f"    output reg  [{min_bit_to_store-1}:0]grant")
        if switch_policy == "CE":
            out.write(",\n")
            out.write("    input       ce\n")
        else:
            out.write("\n")
        out.write(");\n\n")

        indent = 4
        out.write(indent*" " + "initial begin\n")
        indent += 4
        out.write(indent*" " + "grant = 0;\n")
        indent -= 4
        out.write(indent*" " + "end\n\n")

        out.write(indent*" " + "always @(posedge clk or negedge rst_n) begin\n")
        indent += 4
        out.write(indent*" " + "if (!rst_n) begin\n")
        indent += 4
        out.write(indent*" " + "grant <= 0;\n")
        indent -= 4
        out.write(indent*" " + "end\n")
        out.write(indent*" " + "else begin\n")
        indent += 4
        if switch_policy == "CE":
            out.write(indent*" " + "if (ce) begin\n")
            indent += 4
        out.write(indent*" " + "case (grant)\n")
        indent += 4
        for i in range(n):
            out.write(indent*" " + f"{i}: begin\n")
            indent += 4
            if switch_policy == "WITHDRAW":
                out.write(indent*" " + f"if (request{i}) begin\n")
                indent += 4
            switch = []
            for j in reversed(range(i+1, i+n)):
                t = j % n
                switch = [
                    f"if (request{t}) begin\n",
                    f"grant <= {t};\n",
                    "end\n",
                    "else begin\n",
                    *switch,
                    "end\n"
                ]
            for s in switch:
                if "begin" in s:
                    out.write(indent*" " + s)
                    indent += 4
                elif "end" in s:
                    indent -= 4
                    out.write(indent*" " + s)
                else:
                    out.write(indent*" " + s)
            if switch_policy == "WITHDRAW":
                indent -= 4
                out.write(indent*" " + "end\n")
            indent -= 4
            out.write(indent*" " + "end\n")
        indent -= 4
        out.write(indent*" " + "endcase\n")
        if switch_policy == "CE":
            indent -= 4
            out.write(indent*" " + "end\n")
        indent -= 4
        out.write(indent*" " + "end\n")
        indent -= 4
        out.write(indent*" " + "end\n")
        out.write("endmodule\n")



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='A script that generate a round robin verilog module.')

    parser.add_argument('--n', type=int, default=2, help='Number of request line.')
    parser.add_argument('--switch_policy', type=str, default='WITHDRAW', help='Swtich policy, can be WITHDRAW or CE.')
    parser.add_argument('--out', type=str, default="./rr.v", help='Output filename and path')

    args = parser.parse_args()

    rr_verilog_gen(args.n, args.switch_policy, args.out)