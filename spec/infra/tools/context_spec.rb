RSpec.describe Infra::Tools::Connection::Context do
  Context = Infra::Tools::Connection::Context
  it "should work" do
    result = Context.apply "ls ../pocket\ book",
      Context::SudoSu["pocket_book"],
      Context::In["/home/ubuntu/pocket_book"],
      Context::RVM[ruby: "2.4", gemset: "pocket_book"],
      Context::Bundled[]

    expect(result).to eq("sudo su pocket_book -c cd\\ /home/ubuntu/pocket_book\\ \\&\\&\\ /usr/share/rvm/bin/rvm\\ 2.4@pocket_book\\ do\\ bundle\\ exec\\ ls\\ ../pocket\\ book")
  end
end