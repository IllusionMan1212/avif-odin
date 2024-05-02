Decoder:-
 - Figure out how to parse OBU structures (kinda getting there)
    - Implement a bitstream reader
 - Figure out how to apply the metadata to the mdat box.
    - By reading the spec in its entirety.
    - By checking out libheif's code.
Encoder:-


Goals:-
- Fast and optimized
- Reliable and robust (doesn't shit itself and panic when things go wrong, and can handle big data)
- Works on lots of targets (Linux, Windows, Darwin, Wasm, BSDs?)
- Tests?
- Get it merged into the Odin core library?
