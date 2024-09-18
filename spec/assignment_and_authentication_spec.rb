require 'rails_helper'

RSpec.describe CanCanCan::AssignmentAndAuthorization do
  fixtures :users, :vehicles, :parts, :groups, :groups_users, :brands
  let(:normal_user) {
     User.find_by_email('test2@test.test')
  }
  let(:creative_user) {
     User.find_by_email('test3@test.test')
  }
  let(:staff_user) {
     User.find_by_email('test@test.test')
  }
  let(:vehicle_and_user_user) {
     User.find_by_email('test4@test.test')
  }

  it "is available as described_class" do
    expect(described_class).to eq(CanCanCan::AssignmentAndAuthorization)
  end

  describe "staff user" do
    it "should update all attribs for a staff user (including vehicle)" do
      user = staff_user
      ability = staff_user.current_ability
      expect(ability.permitted_attributes(:update, user).sort).to eq([:first_name, :last_name, :vehicles_attributes, :group_ids].sort)

      expect(ability.can?(:update, User, :vehicles_attributes)).to eq(true)
      expect(ability.can?(:update, User, 'vehicles_attributes')).to eq(true)

      # confirm initial state
      expect(user.full_name).to eq("Ben Dana")
      expect(user.vehicles.pluck(:make, :model)).to eq([["Dodge", "Caraven"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]])
      expect(user.vehicles.find_by_model("Caraven").parts.pluck(:name)).to eq(["Engine", "Frame"])
      update_vehicle = user.vehicles.where(make: "Dodge", model: "Caraven").first
      update_part    = update_vehicle.parts.find_by_name("Frame")
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])

      params = {
        user: {
          id: user.id,
          first_name: "Benjamin",
          last_name: "Denar",
          email: "dontupdate@here.there",
          group_ids: user.group_ids + [Group.find_by_name("Notification List B").id],
          # was initially a create vehicle, but SQLite3 had issues with creating the vehicle ID.
          vehicles_attributes: [{
            id: update_vehicle.id,
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              id: update_part.id,
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      service = described_class.new(
        ability,
        :update,
        User.find(user.id),
        ActionController::Parameters.new(params)
      )

      response = service.call
      expect(response).to eq(true)

      # original email, should be unchanged
      user = User.find_by_email('test@test.test')
      expect(user.full_name).to eq("Benjamin Denar")
      expect(user.vehicles.pluck(:make, :model)).to eq(
        [["makey", "modely"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]]
      )
      expect(user.vehicles.find_by_model("modely").parts.pluck(:name)).to eq(["Engine", "Frame (warped)"])
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id, Group.find_by_name("Notification List B").id])
      expect(Part.find_by_name("Frame (warped)").brand_ids).to eq([Brand.find_by_name('Cromwell').id])
    end

    it "should generate error for a staff user w/ new vehicles" do
      user = staff_user
      ability = staff_user.current_ability
      expect(ability.permitted_attributes(:update, user).sort).to eq([:first_name, :last_name, :vehicles_attributes, :group_ids].sort)

      expect(user.current_ability.can?(:update, User, :vehicles_attributes)).to eq(true)
      expect(user.current_ability.can?(:update, User, 'vehicles_attributes')).to eq(true)

      # confirm initial state
      expect(user.full_name).to eq("Ben Dana")
      expect(user.vehicles.pluck(:make, :model)).to eq([["Dodge", "Caraven"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]])
      expect(user.vehicles.find_by_model("Caraven").parts.pluck(:name)).to eq(["Engine", "Frame"])
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])

      params = {
        user: {
          id: user.id,
          first_name: "Benjamin",
          last_name: "Denar",
          email: "dontupdate@here.there",
          group_ids: user.group_ids + [Group.find_by_name("Notification List B").id],
          # was initially a create vehicle, but SQLite3 had issues with creating the vehicle ID.
          vehicles_attributes: [{
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      expect {
        # post(:update, params: params, as: :json)
        service = described_class.new(
          ability,
          :update,
          User.find(user.id),
          ActionController::Parameters.new(params)
        )

        response = service.call
      }.to(
        raise_error(CanCan::AccessDenied)
      )

      user = User.find_by_email('test@test.test')
      expect(user.full_name).to eq("Ben Dana")
      expect(user.vehicles.pluck(:make, :model)).to eq(
        [["Dodge", "Caraven"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]]
      )
      expect(user.vehicles.find_by_model("Caraven").parts.pluck(:name)).to eq(["Engine", "Frame"])
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])
    end

    it "should create some attribs for a staff user when silent erroring" do
      user = staff_user
      ability = staff_user.current_ability
      expect(ability.permitted_attributes(:update, user).sort).to eq([:first_name, :last_name, :vehicles_attributes, :group_ids].sort)

      expect(user.current_ability.can?(:update, User, :vehicles_attributes)).to eq(true)
      expect(user.current_ability.can?(:update, User, 'vehicles_attributes')).to eq(true)

      # confirm initial state
      expect(user.full_name).to eq("Ben Dana")
      expect(user.vehicles.pluck(:make, :model)).to eq([["Dodge", "Caraven"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]])
      expect(user.vehicles.find_by_model("Caraven").parts.pluck(:name)).to eq(["Engine", "Frame"])
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])

      params = {
        user: {
          id: user.id,
          first_name: "Benjamin",
          last_name: "Denar",
          email: "dontupdate@here.there",
          group_ids: user.group_ids + [Group.find_by_name("Notification List B").id],
          # was initially a create vehicle, but SQLite3 had issues with creating the vehicle ID.
          vehicles_attributes: [{
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      CanCanCan::NestedAssignmentAndAuthorization.configure do |config|
        config.silence_raised_errors = true
      end

      service = described_class.new(
        ability,
        :update,
        User.find(user.id),
        ActionController::Parameters.new(params)
      )
      response = service.call
      # response = post(:update, params: params, as: :json)
      expect(response).to eq(true)

      user = User.find_by_email('test@test.test')
      expect(user.full_name).to eq("Benjamin Denar")
      expect(user.vehicles.pluck(:make, :model)).to eq(
        [["Dodge", "Caraven"], ["Tesla", "Roadster"], ["Ford", "Firebird"], ["Honda", "Rebel"]]
      )
      expect(Vehicle.find_by_model("modely")).to eq(nil)
      expect(Vehicle.find_by_make("makey")).to eq(nil)
      # expect(user.vehicles.find_by_model("modely").parts.pluck(:name)).to eq(["Engine", "Frame (warped)"])
      expect(user.group_ids).to eq([Group.find_by_name("Notification List A").id, Group.find_by_name("Notification List B").id])
      # expect(Part.find_by_name("Frame (warped)").brand_ids).to eq([Brand.find_by_name('Cromwell').id])
    end
  end

  describe "normal user" do
    it "should update only user attribs for a normal user" do
      user = normal_user
      ability = normal_user.current_ability
      expect(ability.permitted_attributes(:update, user).sort).to eq([:first_name, :last_name].sort)

      # confirm initial state
      expect(user.full_name).to eq("Victor Frankenstein")
      expect(user.vehicles.sort).to eq([].sort)

      update_vehicle = Vehicle.where(make: "Dodge", model: "Caraven").first
      update_part    = update_vehicle.parts.find_by_name("Frame")

      params = {
        user: {
          id: user.id,
          first_name: "Alen",
          last_name: "Tom",
          email: "dontupdate@here.there",
          group_ids: user.group_ids + [Group.find_by_name("Notification List B").id],
          vehicles_attributes: [{
            id: update_vehicle.id,
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              id: update_part.id,
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      service = described_class.new(
        ability,
        :update,
        User.find(user.id),
        ActionController::Parameters.new(params)
      )
      response = service.call
      expect(response).to eq(true)

      # response = post(:update, params: params, as: :json)
      # expect(response.status).to eq(200)

      user = User.find_by_email('test2@test.test')
      expect(user.full_name).to eq("Alen Tom")
      expect(user.vehicles.sort).to eq([].sort)
      expect(user.group_ids).to eq([])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])
    end
  end

  # NOTE: We're updating the 'normal' user with the creative user auth.
  describe "creative user" do
    it "should not update any attribs for a normal user" do
      user = normal_user
      ability = creative_user.current_ability
      expect(ability.permitted_attributes(:update, user).sort).to eq([])

      # confirm initial state
      expect(user.full_name).to eq("Victor Frankenstein")
      expect(user.vehicles.sort).to eq([].sort)

      update_vehicle = Vehicle.where(make: "Dodge", model: "Caraven").first
      update_part    = update_vehicle.parts.find_by_name("Frame")

      params = {
        user: {
          id: normal_user.id,
          first_name: "Alen",
          last_name: "Tommy",
          email: "dontupdate@here.there",
          group_ids: user.group_ids + [Group.find_by_name("Notification List B").id],
          vehicles_attributes: [{
            id: update_vehicle.id,
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              id: update_part.id,
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      service = described_class.new(
        ability,
        :update,
        User.find(user.id),
        ActionController::Parameters.new(params)
      )
      expect {
        service.call
      }.to(
        raise_error(CanCan::AccessDenied)
      )

      user = User.find_by_email('test2@test.test')
      expect(user.full_name).to eq("Victor Frankenstein")
      expect(user.vehicles.sort).to eq([].sort)
      expect(user.group_ids).to eq([])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])
    end

    it "should fail to create normal user, because can't update vehicle" do
      ability = creative_user.current_ability
      expect(ability.permitted_attributes(:create, User.new).sort).to eq(
        [:first_name, :group_ids, :last_name, :vehicles_attributes, :email].sort
      )

      # confirm initial state
      expect(User.where(first_name: "Alen",last_name: "Tommy").first).to eq(nil)

      update_vehicle = Vehicle.where(make: "Dodge", model: "Caraven").first
      update_part    = update_vehicle.parts.find_by_name("Frame")

      params = {
        user: {
          first_name: "Alen",
          last_name: "Tommy",
          email: "aaga@here.there",
          group_ids: [Group.find_by_name("Notification List B").id],
          vehicles_attributes: [{
            id: update_vehicle.id,
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              id: update_part.id,
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      service = described_class.new(
        ability,
        :create,
        User.new,
        ActionController::Parameters.new(params)
      )
      expect {
        service.call
      }.to(
        raise_error(CanCan::AccessDenied)
      )

      user = User.find_by_email('aaga@here.there')
      expect(user).to be_nil
    end

    it "should create attribs for a normal user, but not update vehicle with silenced error mode" do
      ability = creative_user.current_ability
      expect(ability.permitted_attributes(:create, User.new).sort).to eq(
        [:first_name, :group_ids, :last_name, :vehicles_attributes, :email].sort
      )

      # confirm initial state
      expect(User.where(first_name: "Alen",last_name: "Tommy").first).to eq(nil)

      update_vehicle = Vehicle.where(make: "Dodge", model: "Caraven").first
      update_part    = update_vehicle.parts.find_by_name("Frame")

      params = {
        user: {
          first_name: "Alen",
          last_name: "Tommy",
          email: "aaga@here.there",
          group_ids: [Group.find_by_name("Notification List B").id],
          vehicles_attributes: [{
            id: update_vehicle.id,
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              id: update_part.id,
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      CanCanCan::NestedAssignmentAndAuthorization.configure do |config|
        config.silence_raised_errors = true
      end

      service = described_class.new(
        ability,
        :create,
        User.new,
        ActionController::Parameters.new(params)
      )
      response = service.call
      expect(response).to eq(true)

      user = User.find_by_email('aaga@here.there')
      expect(user).not_to be_nil
      expect(user.full_name).to eq("Alen Tommy")
      expect(user.vehicles.sort).to eq([].sort)
      expect(user.group_ids).to eq([Group.find_by_name("Notification List B").id])
      expect(Part.find_by_name("Frame").brand_ids).to eq([])
    end
  end

  describe "vehicle and user role" do
    it "should create attribs for a normal user and vehicle vehicle, but no parts" do
      ability = vehicle_and_user_user.current_ability
      expect(ability.permitted_attributes(:create, User.new).sort).to eq(
        [:first_name, :last_name, :vehicles_attributes, :group_ids, :email].sort
      )

      create_vehicle_data = {make: "Dodgy", model: "Fun"}
      expect(Vehicle.where(create_vehicle_data).first).to eq(nil)
      part_data = {name: "Frame (warped)"}
      expect(Part.where(part_data).first).to eq(nil)

      params = {
        user: {
          first_name: "Alen",
          last_name: "Tommy",
          email: "aaga@here.there",
          group_ids: [Group.find_by_name("Notification List B").id],
          vehicles_attributes: [{
            make: 'makey',
            model: 'modely',
            parts_attributes: [{
              name: "Frame (warped)",
              brand_ids: [Brand.find_by_name('Cromwell').id],
            }],
          }],
        }
      }

      service = described_class.new(
        ability,
        :create,
        User.new,
        ActionController::Parameters.new(params)
      )
      response = service.call

      expect(response).to eq(true)

      user = User.find_by_email('aaga@here.there')
      expect(user).not_to be_nil
      expect(user.full_name).to eq("Alen Tommy")
      expect(user.vehicles.where(create_vehicle_data).first).to eq(Vehicle.where(create_vehicle_data).first)
      expect(user.group_ids).to eq([Group.find_by_name("Notification List B").id])
      expect(user.parts.where(part_data).first).to eq(nil)
    end
  end

end
