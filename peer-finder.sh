#!/bin/bash

help=false
domain="cluster.local"
service=""
ns=""
script=""
stdout=true
repeat=0
fqdns=()

num_args=$#
input_args=( "${@}" )
for (( i=0; i<num_args; i++ )); do
    this_arg="${input_args[$i]}"
    key=unset_variable
    value=true
    if [[ $this_arg =~ ^--(refresh|istio)$ ]]; then
        key="${BASH_REMATCH[1]}"
    elif [[ $this_arg =~ ^--([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
    elif [[ $this_arg =~ ^--(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        ((i++))
        value="${input_args[$i]}"
    fi

    if [[ $key == "fqdn" ]]; then
        fqdns+=( "$value" )
    else
        echo "Setting $key to $value"
        declare "$key"="$value"
    fi
done

if [[ -z $domain ]] || [[ -z $service ]] || [[ -z $ns ]] && [[ ${fqdns[@]} -eq 0 ]]; then
    echo "Domain, service, or ns are empty and FQDN is not set!"
    help=true
fi >&2

if $help; then
    echo
    echo "Supported Arguments:"
    printf "%15s : %s\n" \
        "--domain" "Domain to search. Defaults to cluster.local" \
        "--service" "Name of service to inspect" \
        "--ns" "Name of namespace to inspect" \
        "--script" "If set, domains are sent via stdin to this script" \
        "--exec" "If set, this command is called each time per domain" \
        "--stdout" "Domains are sent to stdout for logging. Defaults to true" \
        "--repeat" "If greater than 0, will loop forever with this many seconds between each loop. If 0, then only loops once." \
        "--fqdn" "If given, this is what we dig against. Ignors other domain related arguments. Can do multiple --fqdn arguments to dig against multiple domains"
    echo
    echo 'This script basically does a dig on the srv records against: ${service}.${namespace}.svc.${domain} or ${fqdn}'
    exit 2
fi >&2


if [[ ${fqdns[@]} -eq 0 ]]; then
    fqdns=( "${service}.${namespace}.svc.${domain}" )
fi

echo "Going to dig against ${fqdns[@]}" >&2


pipe_target=()
if ! [[ -z $script ]]; then
    echo "Going to pipe output to $script" >&2
    if [[ -x $script ]]; then
        pipe_target="$script"
    elif [[ -e "$script" ]]; then
        echo "The script you want to pipe results to is not executable! Going to run it as a bash script." >&2
        pipe_target=( "bash" "$script" )
    else
        echo "The script you watn to pipe results to ( $script ) does not exist!" >&2
        exit 12
    fi
fi

exec_target=()
if ! [[ -z $exec ]]; then
    echo "Going to run $exec with each domain" >&2
    if [[ -x $exec ]]; then
        exec_target="$exec"
    elif [[ -e "$exec" ]]; then
        echo "The script you watn to exec is not executable! Going to run it with bash." >&2
        exec_target=( "bash" "$exec" )
    else
        echo "The script you want to exec ( $exec ) does not exist!" >&2
        exit 18
    fi
fi

while true; do
    IFS=$'\n' domains=( $( for fqdn in "${fqdns[@]}"; do dig srv "$fqdn" +short | awk '{print $NF}' | sort | uniq | sed 's/.$//'; done ) )
    if $stdout; then
        printf -- "- %s\n" "${domains[@]}"
    fi

    if [[ "${#pipe_target[@]}" -ne 0 ]]; then
        printf "%s\n" "${domains[@]}" | "${pipe_target[@]}" >&2
    fi

    if [[ "${#exec_target[@]}" -ne 0 ]]; then
        for d in "${domains[@]}"; do
            "${exec_target[@]}" "$d" >&2
        done
    fi

    if [[ $repeat -gt 0 ]]; then
        sleep $repeat
    else
        break
    fi
done

