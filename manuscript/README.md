# Manuscript reference

The do-files in CreateTables/BrokerRegistrationRobustness/, which produce Appendix
Table A.7, re-estimate Table IX (the post-merger difference-in-differences table) and
check their own numbers against the published ones. `_settings.do` points `$PAPER` here, and `01_replicate_baseline.do` parses

    Tables/post_misc_regs.tex

to read those published values as comparison targets. It is the only manuscript
file any code in this package reads, and nothing writes to it.
