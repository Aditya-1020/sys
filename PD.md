First run:
- Magic DRC: 2,833,972
- KLayout DRC: 0

Second run:
- Magic DRC: 213
- KLayout DRC: 27
    - Removed level coutners in fifo
    - fixed cycle counters in systolic array
    - added reset propogation and sync resets for spi sepreatly for its clocks
    - configs etc were about the same
- Found a lot of issues with fifo and systolic array in terms of logic dependencies, fanout.
- Third run will feature changes made from analyzing sta, delay buffers removed

