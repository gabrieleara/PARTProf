#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <string.h>
#include <float.h>

#define MAX_SAMPLES 1024

float samples[MAX_SAMPLES];
char line[1024];
int n = 0;

float f(float t, float a, float b1, float b2, float t1, float t2) {
  return a + b1 * (1.0 - exp(-t/t1)) + b2 * (1.0 - exp(-t/t2));
}

float eval_mae(float a, float b1, float b2, float t1, float t2) {
  float err = 0;
  for (int i = 0; i < n; i++) {
    float val = f(i, a, b1, b2, t1, t2);
    err += fabs(val - samples[i]);
  }
  return err / n;
}

void dump_params(float mae, float a, float b1, float b2, float t1, float t2) {
  printf("mae: %f, a=%f, b1=%f, b2=%f, t1=%f, t2=%f\n", mae, a, b1, b2, t1, t2);
  printf("f(x): %f + %f * (1 - exp(-x/%f)) + %f * (1 - exp(-x/%f))\n", a, b1, t1, b2, t2);
}

int main(int argc, char *argv[]) {
  assert(argc == 2);
  FILE *f = fopen(argv[1], "r");
  while (!feof(f) && n < MAX_SAMPLES) {
    assert(fgets(line, sizeof(line), f) != NULL);
    if (strlen(line) > 0 && fscanf(f, "%f", &samples[n]) == 1) {
      samples[n] /= 1000;
      printf("read: %f\n", samples[n]);
      n++;
    }
  }

  float vmin = samples[0];
  float vmax = samples[0];
  for (int i = 1; i < n; i++) {
    if (samples[i] < vmin)
      vmin = samples[i];
    if (samples[i] > vmax)
      vmax = samples[i];
  }

  printf("vmin=%f, max=%f\n", vmin, vmax);

  float oa = vmin, ob1 = 4.78, ob2 = 156, ot1 = 13.167, ot2 = 5;
  float omae = eval_mae(oa, ob1, ob2, ot1, ot2); // FLT_MAX;
  goto skip;
  for (float a = vmin; a < vmax; a += (vmax - vmin) / 10) {
    for (float b1 = 0; b1 < (vmax - vmin) * 0.7; b1 += (vmax - vmin) * 0.7 / 100) {
      for (float b2 = 0; b2 < (vmax - vmin) * 0.7; b2 += (vmax - vmin) * 0.7 / 100) {
        for (float t1 = 1; t1 < 200; t1 *= 1.1) {
          for (float t2 = 1; t2 < 200; t2 *= 1.1) {
            float mae = eval_mae(a, b1, b2, t1, t2);
            //printf("mae: %f, a=%f, b1=%f, b2=%f, t1=%f, t2=%f\n", mae, a, b1, b2, t1, t2);
            if (mae < omae) {
              oa = a;  ob1 = b1; ob2 = b2; ot1 = t1; ot2 = t2;
              omae = mae;
              dump_params(omae, oa, ob1, ob2, ot1, ot2);
            }
          }
        }
      }
    }
    break;
  }

 skip:
  printf("Searching...\n");
  float p, mae;
  float d = 0.1;
  while (d > 1e-9) {
    float old_mae = omae;

    /* p = oa * (1.0 + d); */
    /* mae = eval_mae(p, ob1, ob2, ot1, ot2); */
    /* if (mae < omae) { */
    /*   oa = p; */
    /*   omae = mae; */
    /*   dump_params(omae, oa, ob1, ob2, ot1, ot2); */
    /* } */
    /* p = oa * (1.0 - d); */
    /* mae = eval_mae(p, ob1, ob2, ot1, ot2); */
    /* if (mae < omae) { */
    /*   oa = p; */
    /*   omae = mae; */
    /*   dump_params(omae, oa, ob1, ob2, ot1, ot2); */
    /* } */

    p = ob1 * (1.0 + d);
    mae = eval_mae(oa, p, ob2, ot1, ot2);
    if (mae < omae) {
      ob1 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }
    p = ob1 * (1.0 - d);
    mae = eval_mae(oa, p, ob2, ot1, ot2);
    if (mae < omae) {
      ob1 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }

    p = ob2 * (1.0 + d);
    mae = eval_mae(oa, ob1, p, ot1, ot2);
    if (mae < omae) {
      ob2 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }
    p = ob2 * (1.0 - d);
    mae = eval_mae(oa, ob1, p, ot1, ot2);
    if (mae < omae) {
      ob2 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }

    p = ot1 * (1.0 + d);
    mae = eval_mae(oa, ob1, ob2, p, ot2);
    if (mae < omae) {
      ot1 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }
    p = ot1 * (1.0 - d);
    mae = eval_mae(oa, ob1, ob2, p, ot2);
    if (mae < omae) {
      ot1 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }

    p = ot2 * (1.0 + d);
    mae = eval_mae(oa, ob1, ob2, ot1, p);
    if (mae < omae) {
      ot2 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }
    p = ot2 * (1.0 - d);
    mae = eval_mae(oa, ob1, ob2, ot1, p);
    if (mae < omae) {
      ot2 = p;
      omae = mae;
      dump_params(omae, oa, ob1, ob2, ot1, ot2);
    }

    if (omae == old_mae) {
      d *= 0.1;
      printf("d=%f\n", d);
    }
  }
}
