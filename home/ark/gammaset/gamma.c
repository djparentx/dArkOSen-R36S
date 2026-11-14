#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#define DEFAULT_CARD "/dev/dri/card0"
#define TONE_MIN     2700
#define TONE_MAX     6500

static void print_usage(const char *prog) {
    fprintf(stderr,
        "Usage:\n"
        "  %s -s <gamma> [-t <kelvin>]\n"
        "  %s -r <gamma> -g <gamma> -b <gamma> [-t <kelvin>]\n"
        "  %s -t <kelvin>\n"
        "\n"
        "  gamma values must be between 0.1 and 3.0\n"
        "  kelvin must be between %d and %d (%d = neutral)\n",
        prog, prog, prog, TONE_MIN, TONE_MAX, TONE_MAX);
}

static int validate_gamma(const char *label, float g) {
    if (g < 0.1f || g > 3.0f) {
        fprintf(stderr, "Invalid %s gamma value: %.2f (must be between 0.1 and 3.0)\n", label, g);
        return -1;
    }
    return 0;
}

static double clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }

/* Tanner Helland blackbody approximation, 0..1 per channel */
static void kelvin_raw(int k, double *r, double *g, double *b) {
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

/* Channel multipliers, normalized so TONE_MAX = 1.0,1.0,1.0 */
static void kelvin_mult(int k, double *r, double *g, double *b) {
    double nr, ng, nb;
    kelvin_raw(TONE_MAX, &nr, &ng, &nb);
    kelvin_raw(k, r, g, b);
    *r = clamp01(*r / nr);
    *g = clamp01(*g / ng);
    *b = clamp01(*b / nb);
}

/* Fill a 16-bit ramp: gamma curve scaled by the tone multiplier. */
static void generate_gamma_table(uint16_t *table, int size, float gamma, double mult) {
    for (int i = 0; i < size; i++) {
        double normalized = (double)i / (double)(size - 1);
        double corrected = pow(normalized, 1.0 / gamma) * mult;
        table[i] = (uint16_t)(corrected * 65535.0 + 0.5);
    }
}

int main(int argc, char **argv) {
    int have_single = 0, have_rgb = 0, have_tone = 0;
    float g_single = 1.0f, g_r = 1.0f, g_g = 1.0f, g_b = 1.0f;
    int tone = TONE_MAX;
    int opt;

    while ((opt = getopt(argc, argv, "s:r:g:b:t:")) != -1) {
        switch (opt) {
            case 's': g_single = atof(optarg); have_single = 1; break;
            case 'r': g_r = atof(optarg); have_rgb = 1; break;
            case 'g': g_g = atof(optarg); have_rgb = 1; break;
            case 'b': g_b = atof(optarg); have_rgb = 1; break;
            case 't': tone = atoi(optarg); have_tone = 1; break;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }

    if (!have_single && !have_rgb && !have_tone) {
        fprintf(stderr, "No gamma mode specified\n");
        print_usage(argv[0]);
        return 1;
    }
    if (have_single && have_rgb) {
        fprintf(stderr, "Error: Cannot combine different gamma modes\n");
        return 1;
    }
    if (tone < TONE_MIN || tone > TONE_MAX) {
        fprintf(stderr, "Invalid kelvin value: %d (must be between %d and %d)\n", tone, TONE_MIN, TONE_MAX);
        return 1;
    }

    if (have_single) {
        if (validate_gamma("", g_single) < 0) return 1;
        g_r = g_g = g_b = g_single;
    } else if (have_rgb) {
        if (validate_gamma("r", g_r) < 0) return 1;
        if (validate_gamma("g", g_g) < 0) return 1;
        if (validate_gamma("b", g_b) < 0) return 1;
    }

    double m_r, m_g, m_b;
    kelvin_mult(tone, &m_r, &m_g, &m_b);

    int fd = open(DEFAULT_CARD, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Failed to open DRM device: %s\n", strerror(errno));
        return 1;
    }

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) {
        fprintf(stderr, "Failed to get DRM resources: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    if (res->count_crtcs <= 0) {
        fprintf(stderr, "No CRTCs found\n");
        drmModeFreeResources(res);
        close(fd);
        return 1;
    }

    /* Use the first CRTC, matching a single-display handheld setup. */
    uint32_t crtc_id = res->crtcs[0];
    drmModeCrtc *crtc = drmModeGetCrtc(fd, crtc_id);
    int gamma_size = crtc ? crtc->gamma_size : 256;
    if (gamma_size <= 0) gamma_size = 256;
    if (crtc) drmModeFreeCrtc(crtc);

    uint16_t *r_table = calloc(gamma_size, sizeof(uint16_t));
    uint16_t *g_table = calloc(gamma_size, sizeof(uint16_t));
    uint16_t *b_table = calloc(gamma_size, sizeof(uint16_t));
    if (!r_table || !g_table || !b_table) {
        fprintf(stderr, "Failed to allocate gamma tables\n");
        free(r_table); free(g_table); free(b_table);
        drmModeFreeResources(res);
        close(fd);
        return 1;
    }

    generate_gamma_table(r_table, gamma_size, g_r, m_r);
    generate_gamma_table(g_table, gamma_size, g_g, m_g);
    generate_gamma_table(b_table, gamma_size, g_b, m_b);

    int ret = drmModeCrtcSetGamma(fd, crtc_id, gamma_size, r_table, g_table, b_table);
    if (ret) {
        fprintf(stderr, "Failed to set gamma: %s\n", strerror(-ret));
        free(r_table); free(g_table); free(b_table);
        drmModeFreeResources(res);
        close(fd);
        return 1;
    }

    printf("gamma  R %.2f  G %.2f  B %.2f   tone %4dK  R %.3f  G %.3f  B %.3f\n",
           g_r, g_g, g_b, tone, m_r, m_g, m_b);

    free(r_table); free(g_table); free(b_table);
    drmModeFreeResources(res);
    close(fd);
    return 0;
}
