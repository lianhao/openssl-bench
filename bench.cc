#include <openssl/ssl.h>
#include <openssl/crypto.h>
#include <openssl/err.h>

#include <sys/time.h>

#include <stdio.h>
#include <assert.h>

#include <vector>

static bool chkerr(int err)
{
  if (err == SSL_ERROR_SYSCALL)
  {
    ERR_print_errors_fp(stdout);
    puts("error");
    exit(1);
    return true;
  }
  return err == 0;
}

class Context
{
  ssl_ctx_st *m_ctx;

public:
  Context(ssl_ctx_st *ctx)
    : m_ctx(ctx)
  {
  }

  ~Context()
  {
    SSL_CTX_free(m_ctx);
  }

  ssl_st * open()
  {
    return SSL_new(m_ctx);
  }

  void load_server_creds()
  {
    int err;
    err = SSL_CTX_use_certificate_chain_file(m_ctx, "../rustls/test-ca/rsa/end.fullchain");
    assert(err == 1);
    err = SSL_CTX_use_PrivateKey_file(m_ctx, "../rustls/test-ca/rsa/end.key", SSL_FILETYPE_PEM);
    assert(err == 1);
  }

  void set_ciphers(const char *ciphers)
  {
    SSL_CTX_set_cipher_list(m_ctx, ciphers);
  }

  static Context server()
  {
    return Context(SSL_CTX_new(TLS_server_method()));
  }

  static Context client()
  {
    return Context(SSL_CTX_new(TLS_client_method()));
  }
};

class Conn
{
  ssl_st *m_ssl;
  bio_st *m_reads_from;
  bio_st *m_writes_to;

public:
  Conn(ssl_st *ssl)
    : m_ssl(ssl),
      m_reads_from(BIO_new(BIO_s_mem())),
      m_writes_to(BIO_new(BIO_s_mem()))
  {
    SSL_set0_rbio(m_ssl, m_reads_from);
    SSL_set0_wbio(m_ssl, m_writes_to);
  }

  ~Conn()
  {
    SSL_free(m_ssl);
  }

  bool connect()
  {
    return chkerr(SSL_get_error(m_ssl, SSL_connect(m_ssl)));
  }

  bool accept()
  {
    return chkerr(SSL_get_error(m_ssl, SSL_accept(m_ssl)));
  }

  void transfer(Conn &other)
  {
    std::vector<uint8_t> buf(262144, 0);

    while (true)
    {
      int err = BIO_read(m_writes_to, &buf[0], buf.size());

      if (err == 0 || err == -1)
      {
        break;
      } else if (err > 0) {
        BIO_write(other.m_reads_from, &buf[0], err);
      }
    }
  }

  void dump_cipher()
  {
    printf("negotiated %s with %s\n",
           SSL_get_cipher_version(m_ssl),
           SSL_get_cipher(m_ssl));
  }

  void write(const uint8_t *buf, size_t n)
  {
    chkerr(SSL_get_error(m_ssl,
                         SSL_write(m_ssl, buf, n)));
  }

  void read(uint8_t *buf, size_t n)
  {
    while (n)
    {
      int rd = SSL_read(m_ssl, buf, n);

      assert(rd >= 0);
      buf += rd;
      n -= rd;
    }
  }
};

static void do_handshake(Conn& client, Conn& server)
{
  while (true)
  {
    bool s_connected = server.accept();
    bool c_connected = client.connect();

    if (s_connected && c_connected)
    {
      return;
    }

    client.transfer(server);
    server.transfer(client);
  }
}

static double get_time()
{
  timeval tv;
  gettimeofday(&tv, NULL);

  double v = tv.tv_sec;
  v += double(tv.tv_usec) / 1.e6;
  return v;
}

int main(int argc, char **argv)
{
  Context server_ctx = Context::server();
  Context client_ctx = Context::client();

  server_ctx.set_ciphers(argv[1]);
  server_ctx.load_server_creds();

  Conn server(server_ctx.open());
  Conn client(client_ctx.open());

  do_handshake(client, server);
  client.dump_cipher();

  std::vector<uint8_t> megabyte(1024 * 1024, 0);
  double time_send = 0;
  double time_recv = 0;

  for (int i = 0; i < 1024; i++)
  {
    double t = get_time();
    server.write(&megabyte[0], megabyte.size());
    time_send += get_time() - t;

    t = get_time();
    server.transfer(client);
    client.read(&megabyte[0], megabyte.size());
    time_recv += get_time() - t;
  }

  printf("send: %g MB/s\n", 1024. / time_send);
  printf("recv: %g MB/s\n", 1024. / time_recv);

  return 0;
}