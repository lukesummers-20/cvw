.global fir
fir: 
    addi sp, sp, -16
    sd s0, 0(sp)
    sd s1, 8(sp)
    //comparator for outer loop
    sub t0, a3, a4 //n - m
    addi t0, t0, 1 //n - m + 1
    //comparator for inner loop
    addi t1, a4, -1 //m - 1
    //i and j
    mv t2, x0 //j = 0
    mv t3, x0//i = 0
for1: bgt t2, t0, done1
    mv t4, x0 //y[j] value holder
    li t5, 4
    mul t6, t2, t5
    add t5, t6, a2 //&y[j]
for2: bgt t3, t1, done2
    li t6, 4
    mul t6, t6, t3
    add t6, t6, a1 // &c[i]
    lw t6, 0(t6) //c[i]
    sub s0, t2, t3 //j - i
    add s0, s0, a4 //j - i + m
    addi s0, s0, -1 //j - i + m - 1
    li s1, 4
    mul s0, s0, s1
    add s0, s0, a0//&x[j - i + m - 1]
    lw s0, 0(s0) //x[j - i + (m - 1)]
    mul t6, t6, s0 //c[i] * x[j - i + m - 1]
    srai t6, t6, 31 //(c[i] * x[j - i + m - 1]) >> 31
    li s1, 0xFFFFFFFF
    and t6, t6, s1 //((c[i] * x[j - i + m - 1]) >> 31) & 0xFFFFFFFF
    add t4, t4, t6 //y[j] accumulate
    addi t3, t3, 1 // i + 1
    j for2
done1:
    ld s0, 0(sp)
    ld s1, 8(sp)
    addi sp, sp, 16
    ret
done2:
    sw t4, 0(t5)
    addi t2, t2, 1 //j + 1
    mv t3, x0
    j for1