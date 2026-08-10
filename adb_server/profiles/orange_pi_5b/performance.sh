# Orange Pi 5B (RK3588S) Stable Performance Profile
# Avoids thermal throttling by locking frequencies at ~80% of max.
# All CPUs set to fixed frequency for trial stability.

# CPU Policy 0: Cortex-A55 cores (0-3) - Max 1.8GHz, locking at 1.416GHz
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 1416000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
echo 1416000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq

# CPU Policy 4: Cortex-A76 cores (4-5) - Max 2.25GHz, locking at 1.8GHz
echo performance > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_min_freq
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq

# CPU Policy 6: Cortex-A76 cores (6-7) - Max 2.3GHz, locking at 1.8GHz
echo performance > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq

# GPU: Mali-G610 - Max 1GHz, locking at 700MHz
echo performance > /sys/class/devfreq/fb000000.gpu/governor
echo 700000000 > /sys/class/devfreq/fb000000.gpu/min_freq
echo 700000000 > /sys/class/devfreq/fb000000.gpu/max_freq
