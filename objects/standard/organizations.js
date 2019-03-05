(function() {
  Creator.Objects.organizations = {
    name: "organizations",
    label: "部门",
    icon: "team_member",
    enable_search: true,
    enable_tree: true,
    fields: {
      name: {
        label: "名称",
        type: "text",
        required: true,
        searchable: true,
        index: true,
        sortable: true
      },
      fullname: {
        label: "部门全称",
        type: "text",
        omit: true,
        hidden: true,
        is_name: true
      },
      parent: {
        label: "上级部门",
        type: "lookup",
        reference_to: "organizations",
        sortable: true,
        index: true,
        blackbox: true
      },
      parents: {
        label: "上级部门",
        type: "lookup",
        reference_to: "organizations",
        multiple: true,
        omit: true,
        group: "系统",
        blackbox: true
      },
      children: {
        label: "下级部门",
        type: "lookup",
        reference_to: "organizations",
        multiple: true,
        omit: true,
        group: "系统"
      },
      sort_no: {
        label: "排序号",
        type: "number",
        defaultValue: 100,
        sortable: true
      },
      admins: {
        label: "部门管理员",
        type: "lookup",
        reference_to: "users",
        multiple: true
      },
      users: {
        label: "成员",
        type: "lookup",
        reference_to: "users",
        multiple: true,
        is_wide: true
      },
      company_id: {
        label: "所属单位",
        group: "系统"
      },
      is_company: {
        label: "公司级",
        type: "boolean",
        index: true
      },
      is_group: {
        label: "群组级",
        type: "boolean",
        index: true
      },
      hidden: {
        label: "隐藏",
        type: "boolean"
      }
    },
    list_views: {
      all: {
        columns: ["name", "sort_no", "is_company", "is_group", "admins", "hidden"],
        label: "所有",
        filter_scope: "space",
        sort: [
          {
            "field_name": "sort_no",
            "order": "desc"
          }, {
            "field_name": "name",
            "order": "asc"
          }
        ]
      }
    },
    actions: {
      standard_query: {
        label: "查找",
        visible: false,
        on: "list",
        todo: "standard_query"
      },
      addSubOrganization: {
        label: "添加子部门",
        visible: function() {
          var permissions;
          permissions = Creator.getPermissions();
          if (permissions) {
            return permissions["allowCreate"];
          }
        },
        on: "record",
        todo: function(object_name, record_id) {
          var record;
          if (record_id) {
            if (Steedos.isMobile()) {
              record = Creator.getObjectRecord(object_name, record_id);
              Session.set('cmDoc', {
                parent: record._id
              });
              Session.set('reload_dxlist', false);
              return Meteor.defer(function() {
                return $(".btn.creator-add").click();
              });
            } else {
              if (this.record) {
                Session.set('cmDoc', {
                  parent: this.record._id
                });
                return Meteor.defer(function() {
                  return $(".btn.creator-add").click();
                });
              }
            }
          }
        }
      }
    },
    permission_set: {
      user: {
        allowCreate: false,
        allowDelete: false,
        allowEdit: false,
        allowRead: true,
        modifyAllRecords: false,
        viewAllRecords: true
      },
      admin: {
        allowCreate: true,
        allowDelete: true,
        allowEdit: true,
        allowRead: true,
        modifyAllRecords: true,
        viewAllRecords: true
      },
      organization_admin: {
        allowCreate: true,
        allowDelete: true,
        allowEdit: true,
        allowRead: true,
        modifyCompanyRecords: true,
        viewAllRecords: true
      }
    }
  };
}).call(this);