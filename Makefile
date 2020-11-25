CXXFLAGS+=-g -Wall -Werror -O2

#CPPFLAGS+=-I$(OPENSSL_DIR)/include
#LDFLAGS+=-L$(OPENSSL_DIR)/lib
#LDFLAGS+=-L/lib/x86_64-linux-gnu
#LDFLAGS+="-Wl,-rpath=$(OPENSSL_DIR)/lib"
LDLIBS+=-lssl -lcrypto -ldl -lpthread
#ENV=env LD_LIBRARY_PATH=$(OPENSSL_DIR)
ENV_QAT=env USE_ENGINE=qatengine
MEMUSAGE=/usr/bin/time -f %M

bench: bench.cc
perf.data: bench
	$(ENV) perf record -F9999 --call-graph dwarf -- ./bench bulk ECDHE-RSA-AES128-GCM-SHA256 1048576
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-aes128-openssl.svg

extra:
	perf record -F9999 --call-graph dwarf -- $(ENV) ./bench bulk ECDHE-RSA-AES256-GCM-SHA384 1048576
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-aes256-openssl.svg
	perf record -F9999 --call-graph dwarf -- $(ENV) ./bench bulk ECDHE-RSA-CHACHA20-POLY1305 1048576
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-chacha-openssl.svg
	perf record -F9999 --call-graph dwarf -- $(ENV) ./bench handshake ECDHE-RSA-AES256-GCM-SHA384
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-fullhs-openssl.svg
	perf record -F9999 --call-graph dwarf -- $(ENV) ./bench handshake-resume ECDHE-RSA-AES256-GCM-SHA384
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-resume-openssl.svg
	perf record -F9999 --call-graph dwarf -- $(ENV) ./bench handshake-ticket ECDHE-RSA-AES256-GCM-SHA384
	perf script | ~/FlameGraph/stackcollapse-perf.pl | ~/FlameGraph/flamegraph.pl > perf-ticket-openssl.svg

measure: bench
	$(ENV) ./bench bulk ECDHE-RSA-AES128-GCM-SHA256 1048576
	$(ENV) ./bench bulk ECDHE-RSA-AES256-GCM-SHA384 1048576
	$(ENV) ./bench bulk ECDHE-RSA-CHACHA20-POLY1305 1048576
	$(ENV) ./bench bulk TLS_AES_256_GCM_SHA384 1048576
	$(ENV) ./bench handshake ECDHE-RSA-AES256-GCM-SHA384
	$(ENV) ./bench handshake-resume ECDHE-RSA-AES256-GCM-SHA384
	$(ENV) ./bench handshake-ticket ECDHE-RSA-AES256-GCM-SHA384
	$(ENV) ./bench handshake TLS_AES_256_GCM_SHA384
	$(ENV) ./bench handshake-resume TLS_AES_256_GCM_SHA384
	$(ENV) ./bench handshake-ticket TLS_AES_256_GCM_SHA384

measure-qat: bench
	$(ENV_QAT) ./bench bulk ECDHE-RSA-AES128-GCM-SHA256 1048576
	$(ENV_QAT) ./bench bulk ECDHE-RSA-AES256-GCM-SHA384 1048576
	$(ENV_QAT) ./bench bulk ECDHE-RSA-CHACHA20-POLY1305 1048576
	$(ENV_QAT) ./bench bulk TLS_AES_256_GCM_SHA384 1048576
	$(ENV_QAT) ./bench handshake ECDHE-RSA-AES256-GCM-SHA384
	$(ENV_QAT) ./bench handshake-resume ECDHE-RSA-AES256-GCM-SHA384
	$(ENV_QAT) ./bench handshake-ticket ECDHE-RSA-AES256-GCM-SHA384
	$(ENV_QAT) ./bench handshake TLS_AES_256_GCM_SHA384
	$(ENV_QAT) ./bench handshake-resume TLS_AES_256_GCM_SHA384
	$(ENV_QAT) ./bench handshake-ticket TLS_AES_256_GCM_SHA384


memory: bench
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 100
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 1000
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 5000
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 100
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 1000
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 5000

memory-qat: bench
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 100
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 1000
	$(ENV) $(MEMUSAGE) ./bench memory ECDHE-RSA-AES256-GCM-SHA384 5000
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 100
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 1000
	$(ENV) $(MEMUSAGE) ./bench memory TLS_AES_256_GCM_SHA384 5000

clean:; rm -f bench *.o
