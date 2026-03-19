module Paginatable
  extend ActiveSupport::Concern

  private

  def paginate(scope, param_name: :page, per_page: 10)
    page = (params[param_name] || 1).to_i
    total = scope.count
    records = scope.offset((page - 1) * per_page).limit(per_page)
    { records: records, page: page, per_page: per_page, total: total,
      total_pages: (total.to_f / per_page).ceil, param_name: param_name }
  end
end
