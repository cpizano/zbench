# ZBench

This is a Zig program to perform microbenchmarks of the standard library. Currently it only benchmarks staticStringMap, but
it could do more in the future.

The idea is that you have two versions of the standard library: upstream and yours (with your changes) and you build the
binary `zbench` twice, one with each version of the library. The root module exports facilities to make your benchmarks
more reliable.

## What exactly am I getting?

1. The `StatsFilter` class. It takes some samples and produces 3 values. The mean, the standard deviation and the
uncertainty. It filters the noise by retaining samples that reduce the standard deviation.
2. How to use the above code.
3. The hard won knowledge that benchmarking on MacOS is hard. To mitigate that we use `taskpolicy` for force running
the code in the efficiency cores. 

## Limitations

- Ony runs in MacOS :(
- Only known to work on a M1 Mac.
- Itself it is not tested.

## Using it.
1. Modify `bench_it.sh` to point to your version of the std lib.
2. Run the `bench_it.sh` script.

Example run

```
 ~/src/zbench main $ ./bench_it.sh
new:
benchmarking zig code.
  toolchain : 0.14.0-dev.3204+c2a3d8cbb
staticStringMap:
  mean = 7921.28 uS,  per item = 36.22 nS
  stdev 4024.55 uS, uncertainty 1006.14 uS
old:
benchmarking zig code.
  toolchain : 0.14.0-dev.3204+c2a3d8cbb
staticStringMap:
  mean = 8570.40 uS,  per item = 39.18 nS
  stdev 3939.93 uS, uncertainty 984.98 uS
done.
```
