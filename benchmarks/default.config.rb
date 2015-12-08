rbenv '2.2.3'

rbenv 'jruby-9.0.4.0-indy',
      'jruby-9.0.4.0',
      '-Xcompile.invokedynamic=true'

rbenv 'rbx-2.5.8'

rbenv 'jruby-dev-truffle-graal',
      'jruby-master+graal-dev',
      '-J-Xmx2G -X+T'

binary 'baseline', 'false'


rubies = ['baseline', '2.2.3', 'jruby-9.0.4.0-indy', 'rbx-2.5.8']
rubies = ['2.2.3', 'jruby-9.0.4.0-indy', 'rbx-2.5.8']
implementation_group 'rubies', *rubies
implementation_group 'rubies+truffle', *rubies, 'jruby-dev-truffle-graal'

