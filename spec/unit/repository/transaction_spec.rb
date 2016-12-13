RSpec.describe ROM::Repository, '#transaction' do
  subject(:repo) do
    Class.new(ROM::Repository) { relations :users, :posts, :labels }.new(rom)
  end

  include_context 'database'
  include_context 'relations'

  describe 'with :create command' do
    let(:user_changeset) do
      repo.changeset(:users, name: 'Jane')
    end

    it 'saves data in a transaction' do
      result = repo.transaction do |t|
        t.create(user_changeset)
      end

      expect(result.to_h).to eql(id: 1, name: 'Jane')
    end
  end

  describe 'with :update command' do
    let(:user_changeset) do
      repo.changeset(:users, user.id, user.to_h.merge(name: 'Jane Doe'))
    end

    let(:user) do
      repo.users.where(name: 'Jane').one
    end

    before do
      repo.command(:create, repo.users).call(name: 'John')
      repo.command(:create, repo.users).call(name: 'Jane')
    end

    it 'saves data in a transaction' do
      result = repo.transaction do |t|
        t.update(user_changeset)
      end

      updated_user = repo.users.fetch(user.id)

      expect(updated_user).to eql(id: 2, name: 'Jane Doe')
    end
  end

  describe 'with :delete command' do
    let(:user) do
      repo.users.where(name: 'Jane').one
    end

    before do
      repo.command(:create, repo.users).call(name: 'John')
      repo.command(:create, repo.users).call(name: 'Jane')
    end

    it 'saves data in a transaction' do
      result = repo.transaction do |t|
        t.delete(repo.users.by_pk(user.id))
      end

      expect(repo.users.by_pk(user.id).one).to be(nil)
      expect(repo.users.count).to be(1)
    end
  end

  describe 'creating a user with its posts' do
    let(:posts_changeset) do
      repo.changeset(:posts, [{ title: 'Post 1' }, { title: 'Post 2' }])
    end

    let(:user_changeset) do
      repo.changeset(:users, name: 'Jane')
    end

    it 'saves data in a transaction' do
      repo.transaction do |t|
        t.create(user_changeset).associate(posts_changeset, :author)
      end

      user = repo.users.combine(:posts).one

      expect(user.name).to eql('Jane')
      expect(user.posts.size).to be(2)
      expect(user.posts[0].title).to eql('Post 1')
      expect(user.posts[1].title).to eql('Post 2')
    end
  end

  describe 'creating a user with its posts and their labels' do
    let(:posts_changeset) do
      repo.changeset(:posts, [{ title: 'Post 1' }])
    end

    let(:labels_changeset) do
      repo.changeset(:labels, [{ name: 'red' }, { name: 'green' }])
    end

    let(:user_changeset) do
      repo.changeset(:users, name: 'Jane')
    end

    it 'saves data in a transaction' do
      repo.transaction do |t|
        t.create(user_changeset)
          .associate(posts_changeset, :author)
          .associate(labels_changeset, :posts)
      end

      user = repo.users.combine(posts: [:labels]).one

      expect(user.name).to eql('Jane')
      expect(user.posts.size).to be(1)
      expect(user.posts[0].title).to eql('Post 1')
      expect(user.posts[0].labels.size).to be(2)
      expect(user.posts[0].labels[0].name).to eql('red')
      expect(user.posts[0].labels[1].name).to eql('green')
    end

    context 'with invalid data' do
      let(:posts_changeset) do
        repo.changeset(:posts, [{ title: nil }])
      end

      it 'rolls back the transaction' do
        expect {
          repo.transaction do |t|
            t.create(user_changeset)
              .associate(posts_changeset, :author)
              .associate(labels_changeset, :posts)
          end
        }.to raise_error(ROM::SQL::ConstraintError)

        expect(repo.users.count).to be(0)
        expect(repo.posts.count).to be(0)
        expect(repo.labels.count).to be(0)
      end
    end
  end
end
