# Instructions

- `make build` to build the image tagged as `img1`
- Add a real API key to `docker-compose.yml`
- `docker-compose up` to launch the container
- Simulate the health check being hit: `while true; do curl http://localhost:8080/health; sleep 1; done`

# Notes

The script `051-datadog.sh` does runtime configuration on container start.  Among other things, it computes host tags based on environment variables.  For local running with `docker-compose`, a simulation of what our service actually encounters is in `ddtags.env`.

When run in our DC/OS environment the `/opt/datadog-agent/agent/agent.py` leaks memory at roughly 3mb per hour.