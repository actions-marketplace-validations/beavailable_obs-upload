#!/usr/bin/bash
set -euo pipefail
shopt -s inherit_errexit

# $@: arguments
_curl() {
    curl -sS --fail-early --fail-with-body -K - -H 'Accept: application/xml; charset=utf-8' "$@" <<EOF
user="$OBS_USERNAME:$OBS_PASSWORD"
EOF
}
prepare_files() {
    local format package version
    case "$OBS_TYPE" in
        deb)
            format=$(cat debian/source/format)
            package=${GITHUB_REPOSITORY##*/}
            version=$(sed -nE '1s/^\S+ \((\S+)\).+$/\1/p' debian/changelog)
            case "$format" in
                '3.0 (native)')
                    dpkg-source -b .
                    OBS_FILES="$OBS_FILES ../${package}_$version.dsc ../${package}_$version.tar.xz"
                    ;;
                '3.0 (quilt)')
                    git archive --format=tar --prefix="${package}-${version%-*}/" HEAD $(git ls-tree --name-only HEAD | grep -v '^debian$') | xz >../${package}_${version%-*}.orig.tar.xz
                    dpkg-source -b .
                    OBS_FILES="$OBS_FILES ../${package}_$version.dsc ../${package}_$version.debian.tar.xz ../${package}_${version%-*}.orig.tar.xz"
                    ;;
                *)
                    echo "Unsupported format: $format" >&2
                    exit 1
                    ;;
            esac
            ;;
        '') ;;
        *)
            echo "Unknown type: $OBS_TYPE" >&2
            exit 1
            ;;
    esac
}
upload() {
    local url files_to_delete files_to_upload
    url="$OBS_APIURL/source/$OBS_PROJECT/$OBS_PACKAGE"

    _curl -F 'cmd=deleteuploadrev' "$url"
    files_to_delete=$(_curl "$url" | sed -nE 's/^\s+<entry name="([^"]+)".+$/\1/p' | paste -sd ',')
    if [[ -n "$files_to_delete" ]]; then
        _curl -X DELETE "$url/{$files_to_delete}?rev=upload"
    fi
    files_to_upload=$(ls $OBS_FILES | paste -sd ',')
    _curl -T "{$files_to_upload}" --url-query '+rev=upload' "$url/"
    _curl -F 'cmd=commit' "$url"
}

prepare_files
if [[ -z "$OBS_FILES" ]]; then
    echo 'No files provided' >&2
    exit 1
fi

retries=0
while [[ $retries -lt 3 ]]; do
    if upload; then
        exit
    fi
    ((++retries))
    echo 'Uploading failed, sleeping 10 seconds...' >&2
    sleep 10
    echo "Retrying: $retries" >&2
done

exit 1
