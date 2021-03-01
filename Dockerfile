FROM cirnoix/lnp-heroku

COPY 1.conf /home/Software/
COPY 2.conf /home/Software/
COPY 3.conf /home/Software/
COPY supervisor.programs.ini /etc/supervisor.d/
COPY start.sh /

RUN chmod +x /start.sh
USER myuser
CMD ["/start.sh"]
