#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <chromaprint.h>

int main(void)
{
    int16_t zeroes[1024] = { 0 };
    char *fingerprint = NULL;
    int result = 1;
    ChromaprintContext *ctx = chromaprint_new(CHROMAPRINT_ALGORITHM_TEST2);
    if(ctx == NULL) {
        return 1;
    }
    if(!chromaprint_start(ctx, 44100, 1)) {
        goto cleanup;
    }
    for(int i = 0; i < 130; i++) {
        if(!chromaprint_feed(ctx, zeroes, 1024)) {
            goto cleanup;
        }
    }
    if(!chromaprint_finish(ctx) || !chromaprint_get_fingerprint(ctx, &fingerprint)) {
        goto cleanup;
    }
    if(strcmp(fingerprint, "AQAAA0mUaEkSRZEGAA") != 0) {
        fprintf(stderr, "unexpected silence fingerprint: %s\n", fingerprint);
        goto cleanup;
    }
    puts(fingerprint);
    result = 0;
cleanup:
    if(fingerprint != NULL) {
        chromaprint_dealloc(fingerprint);
    }
    chromaprint_free(ctx);
    return result;
}
