# 使用官方 nginx alpine 版本作為 base image
FROM nginx:alpine

RUN echo "Hello SRE!" > /usr/share/nginx/html/sre.txt

# Unroot, 把User 改給Nginx User
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# 將 nginx 監聽 port 從 80 改為 8080
RUN sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf

# 切換非 root 的 nginx user
USER nginx

EXPOSE 8080
