# HighLoad Cup 2017, round 1

Crystal implementation.

See also [HighLoad Cup](https://highloadcup.ru/round/1/).

## Build

```bash
docker build . -t cup1
```

## Run

```bash
docker run -p 8080:80 -t cup1
```

Now available at localhost:8080

## Stop

```bash
docker stop $(docker ps -a -q --filter ancestor=cup1)
```

## See also

* [How to test, sample data](https://github.com/sat2707/hlcupdocs).
* [Third-party test tool](https://github.com/AterCattus/highloadcup_tester).
