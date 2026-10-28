# ForjaApp Servidor en la nube (Render). Compila la web de ForjaApp y el
# servidor, y deja una imagen pequeña con solo el ejecutable y la web.
# (cirruslabs no publicó la 3.27.4; la 3.27.3 es de la misma versión de Flutter)
FROM ghcr.io/cirruslabs/flutter:3.27.3 AS compilar
WORKDIR /src

# Primero las dependencias, para que Docker las reutilice entre compilaciones.
COPY pubspec.yaml pubspec.lock ./
COPY servidor/pubspec.yaml servidor/pubspec.lock servidor/
RUN flutter pub get && cd servidor && flutter pub get

COPY . .
RUN flutter build web --release --base-href /
RUN cd servidor && dart compile exe bin/servidor.dart -o /out/servidor

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 forja
COPY --from=compilar /out/servidor /app/servidor
COPY --from=compilar /src/build/web /app/web
USER forja

# Render pone PORT y está delante como proxy. La base de datos
# (DATABASE_URL) y la contraseña inicial de gerencia (ADMIN_CONTRASENA) se
# configuran en Render, nunca aquí. El plan gratuito tiene poca CPU: el hash
# de contraseñas usa 100.000 iteraciones para que el login no tarde 20 s.
ENV TRAS_PROXY=1 PBKDF2_ITERACIONES=100000 PORT=10000
EXPOSE 10000
CMD ["/app/servidor", "--web", "/app/web"]
