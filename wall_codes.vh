localparam WALL    = 9'b111_111_111; // white
localparam OPEN    = 9'b000_000_000; // black
localparam START   = 9'b000_111_111; // cyan
localparam GOAL    = 9'b111_000_111; // violet
localparam VISITED = 9'b000_000_111; // blue
localparam CURRENT = 9'b111_111_000; // yellow
localparam PATH    = 9'b000_111_000; // green

localparam CODE_WALL    = 3'b000;
localparam CODE_OPEN    = 3'b001;
localparam CODE_START   = 3'b010;
localparam CODE_GOAL    = 3'b011;
localparam CODE_VISITED = 3'b100;
localparam CODE_CURRENT = 3'b101;
localparam CODE_PATH    = 3'b110;