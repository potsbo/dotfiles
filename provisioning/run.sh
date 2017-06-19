#!/bin/sh

cd "$(dirname $0)"

CMD=('ansible-playbook')
RTUN='reattach-to-user-namespace'

if [ -n "${TMUX:-}" ] && command -v $RTUN > /dev/null 2>&1; then
	CMD=($RTUN ${CMD[@]})
fi

ARGS=('')
for a in "$@"; do
	ARGS=(${ARGS[@]} "$a")
done

${CMD[@]} ${ARGS[@]} playbook.yml
