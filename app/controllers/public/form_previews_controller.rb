class Public::FormPreviewsController < PublicController
  def show
    render 'public/forms/show', layout: 'public_form'
  end
end
