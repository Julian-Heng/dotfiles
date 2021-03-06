#!/usr/bin/env bash

get_window_size()
{
    mapfile -t sizes < <(tmux list-windows -F '#{window_width}')
    window_size="${sizes[0]}"
}

get_status_length()
{
    printf -v tmp "%s" "${*}"
    length="$((${#tmp} + (2 * (${#*} + 1))))"
    printf "%d" "${length}"
}

use_sys_line()
{
    out_fmt=(
        $'| {cpu.load_avg}{cpu.temp? | {}°C}{mem.percent[round=0]? | Mem: {mem.used[prefix=GiB,round=2]} ({}%)}{disk.percent[round=0]? | {disk.dev[short]}: {disk.used[prefix=GiB,round=2]} ({}%)} | {date.date} | {date.time} |'
        $'| {cpu.load_avg[short]}{cpu.temp? | {}°C}{mem.percent[round=0]? | Mem: {}%}{disk.percent[round=0]? | Disk: {}%} | {date.date} | {date.time} |'
    )

    mapfile -t out < <(sys-line "${out_fmt[@]}")
    printf "%s" "${out[$((${#out[0]} < (window_size / 2) ? 0 : 1))]}"
}

use_show_scripts()
{
    script_dir="$(type -p show_cpu)"
    script_dir="${script_dir%/*}"
    script_dir="${script_dir:-${HOME}/.dotfiles/scripts/info}"

    mapfile -t cpu_info < <(bash "-$-" "${script_dir}/show_cpu" load temp)
    mapfile -t mem_info < <(bash "-$-" "${script_dir}/show_mem" --prefix GiB --round 2 mem_used mem_percent)
    mapfile -t disk_info < <(bash "-$-" "${script_dir}/show_disk" --short-device disk_device disk_used disk_percent)

    mem_info[1]="${mem_info[1]/'%'}"
    disk_info[2]="${disk_info[2]/'%'}"

    if (($(get_status_length "${cpu_info[@]}" "${mem_info[@]}" "${disk_info[@]}") < (window_size / 2))); then
        printf -v cpu_out "| %s " "${cpu_info[@]}"
        printf -v mem_out "| Mem: %s (%.*f%%) " "${mem_info[0]}" "0" "${mem_info[1]}"
        printf -v disk_out "| %s: %s (%.*f%%) " "${disk_info[0]}" "${disk_info[1]}" "0" "${disk_info[2]}"
    else
        printf -v cpu_out "| %s " "${cpu_info[0]%% *}" "${cpu_info[@]:1}"
        printf -v mem_out "| Mem: %.*f%% " "0" "${mem_info[1]}"
        printf -v disk_out "| Disk: %.*f%% " "0" "${disk_info[2]}"
    fi

    printf -v time_out "| %(%a, %d %h)T | %(%H:%M)T |" "-1"
    time_out="${time_out:-$(date '+| %a, %d %h | %H:%M |')}"

    printf "%s" "${cpu_out}" "${mem_out}" "${disk_out}" "${time_out}"
}

main()
{
    get_window_size

    if type -p sys-line > /dev/null 2>&1; then
        output="$(use_sys_line)"
    else
        output="$(use_show_scripts)"
    fi

    printf "%s" "${output}"
}

main
