// fma16_testgen.c
// David_Harris 8 February 2025
// Generate tests for 16-bit FMA
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include "softfloat.h"
#include "softfloat_types.h"

typedef union sp {
  float32_t v;
  float f;
} sp;

// lists of tests, terminated with 0x8000
uint16_t easyExponents[] = {15, 0x8000};
uint16_t easyFracts[] = {0, 0x200, 0x8000}; // 1.0 and 1.1
uint16_t medMulExponents[] = {8, 15, 16, 22, 0x8000};
uint16_t medMulFracts[] = {0, 0x0F0, 0x2C0, 0x3FF, 0x8000};
uint16_t medAddExponents[] = {2, 15, 16, 29, 0x8000};
uint16_t medAddFracts[] = {0, 0x0F0, 0x2C0, 0x3FE, 0x8000};
uint16_t medFmaExponents[] = {8, 15, 16, 22, 0x8000};
uint16_t medFmaFracts[] = {0, 0x0F0, 0x2C0, 0x3F8, 0x8000};
uint16_t specialExponents[] = {0, 1, 15, 16, 30, 31, 0x8000};
uint16_t specialFracts[] = {0, 0x200, 0x0F0, 0x8000};


void softfloatInit(void) {
    softfloat_roundingMode = softfloat_round_minMag; 
    softfloat_exceptionFlags = 0;
    softfloat_detectTininess = softfloat_tininess_beforeRounding;
}

float convFloat(float16_t f16) {
    float32_t f32;
    float res;
    sp r;

    // convert half to float for printing
    f32 = f16_to_f32(f16);
    r.v = f32;
    res = r.f;
    return res;
}

void genCase(FILE *fptr, float16_t x, float16_t y, float16_t z, int mul, int add, int negp, int negz, int roundingMode, int zeroAllowed, int infAllowed, int nanAllowed) {
    float16_t result, tempY, tempZ;
    int op, flagVals;
    char calc[100], flags[80];
    float32_t x32, y32, z32, r32;
    float xf, yf, zf, rf;
    float16_t smallest;

    if (!mul) {
        tempY.v = y.v;
        y.v = 0x3C00; // force y to 1 to avoid multiply
    }
    if (!add) {
        tempZ.v = z.v;
        z.v = 0x0000; // force z to 0 to avoid add
    }
    if (negp) x.v ^= 0x8000; // flip sign of x to negate p
    if (negz) z.v ^= 0x8000; // flip sign of z to negate z
    op = roundingMode << 4 | mul<<3 | add<<2 | negp<<1 | negz;
//    printf("op = %02x rm %d mul %d add %d negp %d negz %d\n", op, roundingMode, mul, add, negp, negz);
    softfloat_exceptionFlags = 0; // clear exceptions
    // set rounding mode
    switch(roundingMode) {

        case 3: softfloat_roundingMode = softfloat_round_max; break;

        case 2: softfloat_roundingMode = softfloat_round_min; break;

        case 1: softfloat_roundingMode = softfloat_round_near_even; break;
         
        case 0: softfloat_roundingMode = softfloat_round_minMag; break;
    }
    result = f16_mulAdd(x, y, z); // call SoftFloat to compute expected result
    
    if (!mul) y.v = tempY.v;
    if (!add) z.v = tempZ.v; 
    if (negp) x.v ^= 0x8000; // flip sign of x
    if (negz) z.v ^= 0x8000; // flip sign of z

    // Extract expected flags from SoftFloat
    sprintf(flags, "NV: %d OF: %d UF: %d NX: %d", 
        (softfloat_exceptionFlags >> 4) % 2,
        (softfloat_exceptionFlags >> 2) % 2,
        (softfloat_exceptionFlags >> 1) % 2,
        (softfloat_exceptionFlags) % 2);
    // pack these four flags into one nibble, discarding DZ flag
    flagVals = softfloat_exceptionFlags & 0x7 | ((softfloat_exceptionFlags >> 1) & 0x8);

    // convert to floats for printing
    xf = convFloat(x);
    yf = convFloat(y);
    zf = convFloat(z);
    rf = convFloat(result);
    sprintf(calc, "(-1)^%d * %f * (mul * %f + !mul) + ((-1)^%d * add * %f) = %f, add = %d, mul = %d", negp, xf, yf, negz, zf, rf, add, mul);
    // if (mul)
    //     if (add) sprintf(calc, "%f * %f + %f = %f", xf, yf, zf, rf);
    //     else     sprintf(calc, "%f * %f + (add * %f) = %f, add = 0", xf, yf, zf, rf);
    // else         sprintf(calc, "%f * (mul * %f + mul) + %f = %f", xf, zf, rf);

    // omit denorms, which aren't required for this project
    smallest.v = 0x0400;
    float16_t resultmag = result;
    resultmag.v &= 0x7FFF; // take absolute value
    if (f16_lt(resultmag, smallest) && ((resultmag.v & 0x7FFF) != 0x0000)) fprintf (fptr, "// skip denorm output: ");
    if ((f16_lt(x, smallest) && ((x.v & 0x7FFF) != 0x0000)) | (f16_lt(y, smallest) && ((y.v & 0x7FFF) != 0x0000)) | (f16_lt(z, smallest) && ((z.v & 0x7FFF) != 0x0000))) fprintf (fptr, "// skip denorm input: ");
    if ((softfloat_exceptionFlags >> 1) % 2) fprintf(fptr, "// skip underflow: ");

    // skip special cases if requested
    if (resultmag.v == 0x0000 && !zeroAllowed) fprintf(fptr, "// skip zero: ");
    if ((resultmag.v == 0x7C00 || resultmag.v == 0x7BFF) && !infAllowed)  fprintf(fptr, "// Skip inf: ");
    if (resultmag.v >  0x7C00 && !nanAllowed)  fprintf(fptr, "// Skip NaN: ");

    // print the test case
    fprintf(fptr, "%04x_%04x_%04x_%02x_%04x_%01x // %s %s\n", x.v, y.v, z.v, op, result.v, flagVals, calc, flags);
}

void prepTests(uint16_t *e, uint16_t *f, char *testName, char *desc, float16_t *cases, 
               FILE *fptr, int *numCases) {
    int i, j;

    // Loop over all of the exponents and fractions, generating and counting all cases
    fprintf(fptr, "%s", desc); fprintf(fptr, "\n");
    *numCases=0;
    for (i=0; e[i] != 0x8000; i++)
        for (j=0; f[j] != 0x8000; j++) {
            cases[*numCases].v = f[j] | e[i]<<10;
            *numCases = *numCases + 1;
        }
}

void genMulTests(uint16_t *e, uint16_t *f, int sgn, char *testName, char *desc, int roundingMode, int zeroAllowed, int infAllowed, int nanAllowed) {
    int i, j, k, numCases;
    float16_t x, y, z;
    float16_t cases[100000];
    FILE *fptr;
    char fn[80];
 
    sprintf(fn, "work/%s.tv", testName);
    if ((fptr = fopen(fn, "w")) == 0) {
        printf("Error opening to write file %s.  Does directory exist?\n", fn);
        exit(1);
    }
    prepTests(e, f, testName, desc, cases, fptr, &numCases);
    z.v = 0x0000;
    for (i=0; i < numCases; i++) { 
        x.v = cases[i].v;
        for (j=0; j<numCases; j++) {
            y.v = cases[j].v;
            genCase(fptr, x, y, z, 1, 0, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
            if(sgn){
                genCase(fptr, x, y, z, 1, 0, 1, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                y.v ^= (1 << 15);
                genCase(fptr, x, y, z, 1, 0, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                genCase(fptr, x, y, z, 1, 0, 1, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
            }
        }
    }
    fclose(fptr);
}

void genAddTests(uint16_t *e, uint16_t *f, int sgn, char *testName, char *desc, int roundingMode, int zeroAllowed, int infAllowed, int nanAllowed) {
    int i, j, k, numCases;
    float16_t x, y, z;
    float16_t cases[100000];
    FILE *fptr;
    char fn[80];
 
    sprintf(fn, "work/%s.tv", testName);
    if ((fptr = fopen(fn, "w")) == 0) {
        printf("Error opening to write file %s.  Does directory exist?\n", fn);
        exit(1);
    }
    prepTests(e, f, testName, desc, cases, fptr, &numCases);

    y.v = 0x3C00;
    for (i=0; i < numCases; i++) { 
        x.v = cases[i].v;
        for (j=0; j<numCases; j++) {
            z.v = cases[j].v;
            genCase(fptr, x, y, z, 0, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
            if(sgn){
                genCase(fptr, x, y, z, 0, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                z.v ^= (1 << 15);
                genCase(fptr, x, y, z, 0, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                genCase(fptr, x, y, z, 0, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                z.v ^= (1 << 15);
                x.v ^= (1 << 15);
                genCase(fptr, x, y, z, 0, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                genCase(fptr, x, y, z, 0, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
            }
        }
    }
    fclose(fptr);
}

void genFmaTests(uint16_t *e, uint16_t *f, int sgn, char *testName, char *desc, int roundingMode, int zeroAllowed, int infAllowed, int nanAllowed) {
    int i, j, k, l, numCases;
    float16_t x, y, z;
    float16_t cases[100000];
    FILE *fptr;
    char fn[80];
 
    sprintf(fn, "work/%s.tv", testName);
    if ((fptr = fopen(fn, "w")) == 0) {
        printf("Error opening to write file %s.  Does directory exist?\n", fn);
        exit(1);
    }
    prepTests(e, f, testName, desc, cases, fptr, &numCases);
    z.v = 0x0000;
    for (i=0; i < numCases; i++) { 
        x.v = cases[i].v;
        for (j=0; j<numCases; j++) {
            y.v = cases[j].v;
            for (k=0; k<numCases; k++){
                z.v = cases[k].v;
                genCase(fptr, x, y, z, 1, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                if(sgn){
                    genCase(fptr, x, y, z, 1, 1, 1, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 1, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    z.v ^= (1 << 15);
                    genCase(fptr, x, y, z, 1, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 1, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 1, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    z.v ^= (1 << 15);
                    y.v ^= (1 << 15);
                    genCase(fptr, x, y, z, 1, 1, 0, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 1, 0, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 0, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                    genCase(fptr, x, y, z, 1, 1, 1, 1, roundingMode, zeroAllowed, infAllowed, nanAllowed);
                }
            }
        }
    }
    fclose(fptr);
}

int main()
{
    if (system("mkdir -p work") != 0) exit(1); // create work directory if it doesn't exist
    softfloatInit(); // configure softfloat modes
 
    // Test cases: multiplication
    // genMulTests(easyExponents, easyFracts, 0, "fmul_0", "// Multiply with exponent of 0, significand of 1.0 and 1.1, RZ", 0, 0, 0, 0);

/*  // example of how to generate tests with a different rounding mode
    softfloat_roundingMode = softfloat_round_near_even; 
    genMulTests(easyExponents, easyFracts, 0, "fmul_0_rne", "// Multiply with exponent of 0, significand of 1.0 and 1.1, RNE", 1, 0, 0, 0); */

    // Add your cases here
    // genMulTests(medMulExponents, medMulFracts, 0, "fmul_1", "// Multiply positive normalized numbers, RZ", 0, 0, 0, 0);
    // genMulTests(medMulExponents, medMulFracts, 1, "fmul_2", "// Multiply signed normalized numbers, RZ", 0, 0, 0, 0);
    // genAddTests(easyExponents, easyFracts, 0, "fadd_0", "// Add with exponent of 0, RZ", 0, 0, 0, 0);
    // genAddTests(medAddExponents, medAddFracts, 0, "fadd_1", "// Add with positive normalized numbers, RZ", 0, 0, 0, 0);
    // genAddTests(medAddExponents, medAddFracts, 1, "fadd_2", "// Add with signed normalized numbers, RZ", 0, 0, 0, 0);
    // genFmaTests(easyExponents, easyFracts, 0, "fma_0", "// FMA with exponent of 0, RZ", 0, 0, 0, 0);
    // genFmaTests(medFmaExponents, medFmaFracts, 0, "fma_1", "// FMA with positive normalized numbers, RZ", 0, 0, 0, 0);
    // genFmaTests(medFmaExponents, medFmaFracts, 1, "fma_2", "// FMA with signed normalized inputs, RZ", 0, 0, 0, 0);
    // genFmaTests(specialExponents, specialFracts, 1, "fma_special_rz", "// FMA on special inputs/outputs, RZ", 0, 1, 1, 1);
    // genFmaTests(specialExponents, specialFracts, 1, "fma_special_rne", "// FMA on special inputs/outputs, RNE", 1, 1, 1, 1);
    // genFmaTests(specialExponents, specialFracts, 1, "fma_special_rp", "// FMA on special inputs/outputs, RP", 3, 1, 1, 1);
    // genFmaTests(specialExponents, specialFracts, 1, "fma_special_rn", "// FMA on special inputs/outputs, RN", 2, 1, 1, 1);

    //generate random values
    srand(time(NULL));
    for(int i = 0; i < 50; i++) {
        uint16_t randExponents[] = {(uint16_t)(rand() % 32), (uint16_t)(rand() % 32), (uint16_t)(rand() % 32), (uint16_t)(rand() % 32), (uint16_t)(rand() % 32), 0x8000};
        uint16_t randFracts[] = {(uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), 0x8000};
        genFmaTests(randExponents, randFracts, 1, "fma_rand_all", "// FMA on random inputs, RZ", 0, 1, 1, 1);
        genFmaTests(randExponents, randFracts, 1, "fma_rand_all", "// FMA on random inputs, RNE", 1, 1, 1, 1);
        genFmaTests(randExponents, randFracts, 1, "fma_rand_all", "// FMA on random inputs, RP", 3, 1, 1, 1);
        genFmaTests(randExponents, randFracts, 1, "fma_rand_all", "// FMA on random inputs, RN", 2, 1, 1, 1);

    }
    // uint16_t randExponents[] = {(uint16_t)(rand() % 32), (uint16_t)(rand() % 32), (uint16_t)(rand() % 32), 0x8000};
    // uint16_t randFracts[] = {(uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), (uint16_t)(rand() % 1024), 0x8000};
    // genFmaTests(randExponents, randFracts, 1, "fma_rand_rz", "// FMA on random inputs, RZ", 0, 1, 1, 1);
    // genFmaTests(randExponents, randFracts, 1, "fma_rand_rne", "// FMA on random inputs, RNE", 1, 1, 1, 1);
    // genFmaTests(randExponents, randFracts, 1, "fma_rand_rp", "// FMA on random inputs, RP", 3, 1, 1, 1);
    // genFmaTests(randExponents, randFracts, 1, "fma_rand_rn", "// FMA on random inputs, RN", 2, 1, 1, 1);

    return 0;
}
