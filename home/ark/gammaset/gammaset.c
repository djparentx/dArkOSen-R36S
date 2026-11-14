#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static double clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }

/* Tanner Helland blackbody approximation, returns 0..1 per channel */
static void kelvin_raw(int k, double *r, double *g, double *b)
{
    double t = k / 100.0;

    if (t <= 66) *r = 255;
    else         *r = 329.698727446 * pow(t - 60, -0.1332047592);

    if (t <= 66) *g = 99.4708025861 * log(t) - 161.1195681661;
    else         *g = 288.1221695283 * pow(t - 60, -0.0755148492);

    if (t >= 66)      *b = 255;
    else if (t <= 19) *b = 0;
    else              *b = 138.5177312231 * log(t - 10) - 305.0447927307;

    *r = clamp01(*r / 255.0);
    *g = clamp01(*g / 255.0);
    *b = clamp01(*b / 255.0);
}

/* Normalize so 6500K = 1.0,1.0,1.0 */
static void kelvin_mult(int k, double *r, double *g, double *b)
{
    double nr, ng, nb;
    kelvin_raw(6500, &nr, &ng, &nb);
    kelvin_raw(k, r, g, b);
    *r = clamp01(*r / nr);
    *g = clamp01(*g / ng);
    *b = clamp01(*b / nb);
}

static int open_drm(void)
{
    int fd = open("/dev/dri/controlD64", O_RDWR | O_CLOEXEC);
    if (fd >= 0) return fd;
    return open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
}

int main(int argc, char **argv)
{
    int k;

    if (argc != 2) {
        fprintf(stderr, "usage: %s <kelvin 1000-6500> | reset\n", argv[0]);
        return 1;
    }

    if (!strcmp(argv[1], "reset")) k = 6500;
    else k = atoi(argv[1]);

    if (k < 1000 || k > 6500) {
        fprintf(stderr, "kelvin out of range (1000-6500)\n");
        return 1;
    }

    double rm, gm, bm;
    kelvin_mult(k, &rm, &gm, &bm);

    int fd = open_drm();
    if (fd < 0) { perror("open drm"); return 1; }

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) { perror("drmModeGetResources"); close(fd); return 1; }

    int done = 0;
    for (int c = 0; c < res->count_crtcs; c++) {
        drmModeCrtc *crtc = drmModeGetCrtc(fd, res->crtcs[c]);
        if (!crtc) continue;

        int size = crtc->gamma_size;
        if (size > 0) {
            uint16_t *r = malloc(size * sizeof(uint16_t));
            uint16_t *g = malloc(size * sizeof(uint16_t));
            uint16_t *b = malloc(size * sizeof(uint16_t));

            for (int i = 0; i < size; i++) {
                double v = (double)i / (size - 1) * 65535.0;
                r[i] = (uint16_t)(v * rm);
                g[i] = (uint16_t)(v * gm);
                b[i] = (uint16_t)(v * bm);
            }

            if (drmModeCrtcSetGamma(fd, crtc->crtc_id, size, r, g, b))
                perror("drmModeCrtcSetGamma");
            else {
                printf("crtc %-4u  size %-4d  %5dK  R %.3f  G %.3f  B %.3f\n",
                       crtc->crtc_id, size, k, rm, gm, bm);
                done++;
            }

            free(r); free(g); free(b);
        }
        drmModeFreeCrtc(crtc);
    }

    drmModeFreeResources(res);
    close(fd);
    return done ? 0 : 1;
}
