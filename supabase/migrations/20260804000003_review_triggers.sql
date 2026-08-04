-- Migration: 20260804000003_review_triggers.sql
-- Description: Trigger para recálculo automático de rating médio e jobs concluídos no perfil do usuário

CREATE OR REPLACE FUNCTION public.handle_new_review()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET 
    rating = COALESCE((
      SELECT ROUND(AVG(rating)::numeric, 1)
      FROM public.reviews
      WHERE target_id = NEW.target_id
    ), 5.0),
    completed_jobs_count = (
      SELECT COUNT(DISTINCT contract_id)
      FROM public.reviews
      WHERE target_id = NEW.target_id
    ),
    updated_at = NOW()
  WHERE id = NEW.target_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_review_created ON public.reviews;
CREATE TRIGGER on_review_created
AFTER INSERT OR UPDATE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_review();
