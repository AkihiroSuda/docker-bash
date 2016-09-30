#!/bin/bash
set -eu

declare -A aliases=(
	[4.4]='4 latest'
	[3.2]='3'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# sort version numbers with highest first
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -rV) ); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/tianon/docker-bash/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon)
GitRepo: https://github.com/tianon/docker-bash.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	commit="$(dirCommit "$version")"

	fullVersion="$(git show "$commit":"$version/Dockerfile" | awk '
		$1 == "ENV" && $2 == "_BASH_VERSION" {
			bashVersion = $3
		}
		$1 == "ENV" && $2 == "_BASH_LATEST_PATCH" {
			bashLatestPatch = $3
		}
		bashVersion != "" && bashLatestPatch != "" {
			printf "%s.%s", bashVersion, bashLatestPatch;
			exit
		}
	')"

	versionAliases=(
		$fullVersion
		$version
		${aliases[$version]:-}
	)

	echo
	cat <<-EOE
		Tags: $(join ', ' "${versionAliases[@]}")
		GitCommit: $commit
		Directory: $version
	EOE
done
