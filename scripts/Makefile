rudder-setup: rudder-setup-src.sh *.sh
	perl -pe '$$_=qx/cat $$1/ if /^#\s*Include\s*:\s*(\S+)/' $< > $@
	chmod +x $@

clean:
	rm -f rudder-setup

