# Orange Pi 5B (RK3588S) Reset Profile
# Restores default governors and full frequency range.

# Restore CPU Policy 0
echo schedutil > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

# Restore CPU Policy 4
echo schedutil > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo 2256000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq

# Restore CPU Policy 6
echo schedutil > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
echo 408000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
echo 2304000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq

# Restore GPU
echo simple_ondemand > /sys/class/devfreq/fb000000.gpu/governor
echo 300000000 > /sys/class/devfreq/fb000000.gpu/min_freq
echo 1000000000 > /sys/class/devfreq/fb000000.gpu/max_freq
