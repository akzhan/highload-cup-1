# HighLoad Cup 2017, round 1

Crystal implementation.

See also [HighLoad Cup](https://highloadcup.ru/round/1/).

## Build

```bash
docker build . -t cup1
docker run -p 8080:80 -t cup1

```

Now available at localhost:8080

## Stop

```bash
docker stop $(docker ps -a -q --filter ancestor=cup1)
```
