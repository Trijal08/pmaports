/*
 * Stub librga.so.2.
 *
 * Rockchip game ports link against librga, the userspace half of the RGA
 * 2D block, and refuse to start without it: the loader fails the process
 * with "librga.so.2: cannot open shared object file" before main() runs.
 * Alpine has no librga, and airockchip's would not help - it drives
 * /dev/rga from the vendor kernel, while mainline exposes RK3326's RGA2
 * as a V4L2 mem2mem device (CONFIG_VIDEO_ROCKCHIP_RGA) that librga does
 * not speak. A real port of the library would be a V4L2 rewrite.
 *
 * The ports we care about import exactly three entry points and use them
 * for one thing - rotating the scanout when the panel is mounted sideways
 * - and they check the return values. McpeLauncherV2 logs "RGA
 * initialization failed for SDL_KMSDRM_ROTATION=%d" and continues. So
 * failing honestly here costs nothing on a panel that needs no rotation,
 * and keeps the loader happy.
 *
 * Built -nostdlib: no libc is referenced, so the same object loads under
 * musl and under a port's bundled glibc.
 */

/* Pointer-generic on purpose: nothing is dereferenced, so the real
 * rga_info_t layout never becomes part of this ABI. */

int c_RkRgaInit(void)
{
	return -1;
}

int c_RkRgaDeInit(void)
{
	return 0;
}

int c_RkRgaBlit(void *src, void *dst, void *src1)
{
	(void)src;
	(void)dst;
	(void)src1;
	return -1;
}
