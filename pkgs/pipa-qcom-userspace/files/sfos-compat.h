/* Sailfish OS headers omit __packed; force-include this when building MSM userspace. */
#ifndef __packed
#define __packed __attribute__((__packed__))
#endif
